from typing import Optional

class HealthCalculator:
    def calculate_tdee(
        self, 
        weight_kg: float, 
        height_cm: float, 
        age: int, 
        gender: str, 
        activity_level: str,
        # Parametri Livello 2 (Opzionali - possono essere vuoti)
        body_fat_percent: Optional[float] = None,
        avg_daily_steps: Optional[int] = None
    ) -> dict:
        """
        Calcola il TDEE (Dispendio Energetico) usando una logica intelligente a cascata.
        Se abbiamo dati precisi usa formule avanzate, altrimenti usa stime standard.
        """
        bmr = 0.0
        method = ""
        
        # --- A. CALCOLO BMR (Metabolismo Basale) ---
        
        # SCENARIO PREMIUM: Katch-McArdle (se abbiamo % grasso)
        # È molto più preciso perché basa il calcolo sui muscoli veri e non solo sul peso.
        if body_fat_percent is not None and body_fat_percent > 0:
            lean_mass_kg = weight_kg * (1 - (body_fat_percent / 100))
            bmr = 370 + (21.6 * lean_mass_kg)
            method = "Analisi Avanzata (Massa Magra)"
        
        # SCENARIO STANDARD: Mifflin-St Jeor (se abbiamo solo peso/altezza)
        # È lo standard medico per le stime rapide.
        else:
            if gender.upper() == 'M':
                bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
            else:
                bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161
            method = "Stima Standard (Mifflin-St Jeor)"

        # --- B. MOLTIPLICATORE ATTIVITÀ ---
        
        multiplier = 1.2 # Default (Sedentario)
        activity_source = "Dichiarazione Utente"

        # Se abbiamo i passi reali (Livello 2 - Wearable)
        if avg_daily_steps is not None and avg_daily_steps > 0:
            if avg_daily_steps < 5000: multiplier = 1.2
            elif avg_daily_steps < 7500: multiplier = 1.375
            elif avg_daily_steps < 10000: multiplier = 1.55
            else: multiplier = 1.725
            activity_source = "Tracker Passi Reale"
        else:
            # Fallback su dichiarazione utente (quello che ha detto nell'Onboarding)
            multipliers = {
                'Sedentary': 1.2,
                'Moderate': 1.55,
                'Active': 1.725
            }
            # Se activity_level non corrisponde, usa 1.2 come sicurezza
            multiplier = multipliers.get(activity_level, 1.2)

        # Calcolo finale TDEE
        tdee = int(bmr * multiplier)

        return {
            "tdee": tdee,
            "bmr": int(bmr),
            "method": method,
            "activity_source": activity_source
        }

    def calculate_health_impact(self, habit_name: str, daily_quantity: int) -> dict:
        """
        Stima il danno evitato in base al tipo di vizio.
        """
        avg_calories = {
            "fast food": 1200, 
            "alcol": 200,      
            "bevande zuccherate": 140, 
            "snack": 300,
            "dolci": 400,
            "sigarette": 0 # Caso speciale
        }
        
        habit_lower = habit_name.lower()
        saved_kcal = 0
        
        # Cerca corrispondenze parziali (es. "Mangiare snack" -> trova "snack")
        for key, cal in avg_calories.items():
            if key in habit_lower:
                saved_kcal = cal * daily_quantity
                break
        
        # Logica Sigarette (Tempo di vita perso)
        life_minutes_saved = 0
        if "sigarett" in habit_lower or "fum" in habit_lower:
            life_minutes_saved = 11 * daily_quantity 
            
        return {
            "daily_kcal_saved": saved_kcal,
            "daily_life_minutes_saved": life_minutes_saved
        }