from datetime import date, datetime
from dateutil.relativedelta import relativedelta
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# --- MODELLI DATI INTERNI (Domain Objects) ---

class ProfilePreferences(BaseModel):
    enable_windfall: bool = True
    weekend_multiplier: float = 1.0 # 1.0 = Giorni uguali, 1.5 = Weekend costosi
    sugar_tax_rate: float = 1.0     # 1.0 = Nessuna tassa, 1.2 = 20% interesse passivo calorico
    vice_strategy: str = "SOFT"     # SOFT | HARD
    min_viable_sds: float = 5.0     # Soglia di panico

class UserProfile(BaseModel):
    id: str
    tdee_kcal: int
    current_liquid_balance: float
    payday_day: int
    preferences: ProfilePreferences

class Expense(BaseModel):
    id: str
    amount: float
    is_variable: bool = False
    min_amount: float = 0.0
    max_amount: float = 0.0
    payment_months: List[int] = []
    due_day: int = 1

class DailyLog(BaseModel):
    date: str # ISO Date
    log_type: str # vice_consumed, expense, food, workout
    amount: float = 0.0 # Soldi
    calories: int = 0   # Calorie
    category: Optional[str] = None # Es. 'Sugar', 'Alcohol' per la tassa
    related_fixed_expense_id: Optional[str] = None

# --- IL MOTORE CENTRALE ---

class SolvencyManager:
    def __init__(self, profile: UserProfile, expenses: List[Expense], logs: List[DailyLog]):
        self.profile = profile
        self.expenses = expenses
        self.logs = logs
        self.today = date.today()

    def _get_next_payday(self) -> date:
        """
        Calcola il payday gestendo mesi corti (Febbraio) e rollover dell'anno.
        Usa relativedelta per precisione assoluta.
        """
        try:
            # Tentativo 1: Payday in questo mese
            candidate = self.today.replace(day=self.profile.payday_day)
        except ValueError:
            # Fallback: Ultimo giorno del mese se il giorno non esiste (es. 30 Feb)
            candidate = self.today + relativedelta(day=31)

        if candidate > self.today:
            return candidate
        
        # Se è passato, andiamo al mese prossimo
        try:
            return self.today + relativedelta(months=+1, day=self.profile.payday_day)
        except ValueError:
            return self.today + relativedelta(months=+1, day=31)

    def _calculate_weighted_days(self, target_date: date) -> float:
        """
        Calcola i giorni rimanenti "pesati".
        Se il weekend_multiplier è > 1, sabato e domenica "costano" di più in termini di giorni SDS.
        """
        remaining_days = (target_date - self.today).days
        if remaining_days <= 0: return 1.0

        multiplier = self.profile.preferences.weekend_multiplier
        if multiplier == 1.0:
            return float(remaining_days)

        weighted_count = 0.0
        current = self.today
        while current < target_date:
            # 5 = Sabato, 6 = Domenica
            if current.weekday() >= 5:
                weighted_count += multiplier
            else:
                weighted_count += 1.0
            current += relativedelta(days=1)
        
        return weighted_count

    def _is_bill_paid(self, expense_id: str) -> bool:
        """Verifica se una bolletta è stata pagata nel ciclo corrente."""
        # Semplificazione: controlla se c'è un log di pagamento negli ultimi 30gg
        # In produzione: controllare la data rispetto all'ultimo payday
        for log in self.logs:
            if log.related_fixed_expense_id == expense_id:
                return True
        return False

    def calculate_bio_financial_state(self) -> Dict[str, Any]:
        
        # --- 1. SETUP VARIABILI ---
        next_payday = self._get_next_payday()
        weighted_days = self._calculate_weighted_days(next_payday)
        
        # --- 2. ENGINE A: FINANCIAL SOLVENCY ---
        
        pending_liabilities_max = 0.0 # Scenario Pessimista
        pending_liabilities_avg = 0.0 # Scenario Realista
        projected_windfall = 0.0      # Soldi potenzialmente liberabili

        for exp in self.expenses:
            # Filtro temporale: scade questo mese/ciclo?
            if exp.payment_months and self.today.month not in exp.payment_months:
                continue
            
            # Filtro stato: è già pagata?
            if self._is_bill_paid(exp.id):
                continue

            # Calcolo Liability
            if exp.is_variable:
                pending_liabilities_max += exp.max_amount
                avg = (exp.min_amount + exp.max_amount) / 2
                pending_liabilities_avg += avg
                projected_windfall += (exp.max_amount - exp.min_amount)
            else:
                pending_liabilities_max += exp.amount
                pending_liabilities_avg += exp.amount

        # Calcolo SDS Iniziale (Pessimista)
        liquid_cash = self.profile.current_liquid_balance
        sds = (liquid_cash - pending_liabilities_max) / weighted_days
        
        fin_status = "SAFE"
        calc_mode = "PESSIMISTIC_WINDFALL" if self.profile.preferences.enable_windfall else "STANDARD"

        # 🛡️ LAYER 0: BANKRUPTCY GUARD (Death Spiral Prevention)
        if sds < self.profile.preferences.min_viable_sds:
            # OVERRIDE: Passiamo alla modalità media per non spaventare l'utente
            # "Non dirgli che è morto, digli che è grave"
            sds = (liquid_cash - pending_liabilities_avg) / weighted_days
            fin_status = "CRISIS_MANAGEMENT"
            calc_mode = "AVERAGE_FALLBACK"
            
            # Se è ancora sotto zero, capiamo a 0 per UI
            if sds < 0: sds = 0.0

        # --- 3. ENGINE B: BIO-SOLVENCY (Sugar Tax) ---
        
        consumed_today = 0
        workout_credits = 0
        sugar_tax_loss = 0 # Calorie perse per "interessi passivi" (tassa)

        today_str = self.today.isoformat()
        
        for log in self.logs:
            # Filtra solo oggi
            if not log.date.startswith(today_str):
                continue

            if log.log_type == 'workout':
                workout_credits += log.calories
            
            elif log.log_type == 'food' or log.log_type == 'vice_consumed':
                base_kcal = log.calories
                # Applica Sugar Tax
                tax_rate = 1.0
                if log.category in ["Sugar", "Alcohol", "FastFood", "Vizio"]:
                    tax_rate = self.profile.preferences.sugar_tax_rate
                
                final_cost = int(base_kcal * tax_rate)
                sugar_tax_loss += (final_cost - base_kcal)
                consumed_today += final_cost

        sdc_remaining = (self.profile.tdee_kcal + workout_credits) - consumed_today

        # --- 4. ENGINE C: DDA (Dynamic Difficulty & Negotiation) ---
        
        # Calcolo Activity Ratio (Quanto ti sei mosso rispetto al dovuto)
        activity_ratio = 0.0
        if self.profile.tdee_kcal > 0:
            activity_ratio = workout_credits / (self.profile.tdee_kcal * 0.2) # Target arbitrario: 20% del TDEE in sport
            if activity_ratio > 1.0: activity_ratio = 1.0

        vice_status = "UNLOCKED"
        unlock_cost = 0
        message = "Vice access granted. Enjoy responsibly."

        # Logica HARD MODE
        if self.profile.preferences.vice_strategy == "HARD":
            # Se ti sei mosso poco (< 80% del target), il vizio è bloccato
            if activity_ratio < 0.8:
                vice_status = "LOCKED"
                # Calcolo costo di sblocco (The Negotiation)
                # Più sei stato pigro, più devi pagare ora
                unlock_cost = int((1.0 - activity_ratio) * 500) 
                message = f"Protocol Hard active. Burn {unlock_cost} kcal to unlock Vice."

        # --- 5. ASSEMBLAGGIO RISPOSTA ---
        return {
            "financial": {
                "sds_today": round(sds, 2),
                "currency": "EUR",
                "status": fin_status,
                "mode": calc_mode,
                "projected_windfall": round(projected_windfall, 2) if calc_mode == "PESSIMISTIC_WINDFALL" else 0.0,
                "days_until_payday": int(weighted_days) # approx
            },
            "biological": {
                "sdc_remaining": int(sdc_remaining),
                "sugar_tax_paid_today": int(sugar_tax_loss),
                "workout_credits": workout_credits,
                "tdee_base": self.profile.tdee_kcal
            },
            "psychology": {
                "vice_status": vice_status,
                "unlock_cost_kcal": unlock_cost,
                "activity_ratio": round(activity_ratio, 2),
                "message": message
            }
        }