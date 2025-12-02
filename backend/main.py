from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional 
from core.calculator import WealthCalculator
from core.health import HealthCalculator
from core.solvency import SolvencyEngine, SolvencyInput # <--- NUOVO IMPORT

app = FastAPI(title="LEVERAGE API 4.2 - Bio-Financial")

# Configurazione CORS per permettere a Flutter e Render di parlarsi
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inizializziamo i motori
wealth_calc = WealthCalculator(interest_rate=0.07)
health_calc = HealthCalculator()
solvency_engine = SolvencyEngine() # <--- Istanza Motore Solvibilità

# --- MODELLI DATI ---

# Modello per la proiezione a lungo termine (Livello 1/2)
class UserDataInput(BaseModel):
    # Livello 1 (Obbligatorio)
    age: int
    gender: str
    weight_kg: float
    height_cm: float
    activity_level: str
    
    # Livello 2 (Opzionale - Default None)
    body_fat_percent: Optional[float] = None
    avg_daily_steps: Optional[int] = None
    
    # Dati Vizio
    habit_name: str
    habit_cost: float
    daily_quantity: int

# --- ENDPOINTS ---

@app.get("/")
def read_root():
    return {"status": "online", "version": "4.2 Solvency Active"}

# ENDPOINT 1: Proiezione Ricchezza e Salute (Lungo Termine)
@app.post("/calculate-projection")
def calculate_impact(data: UserDataInput):
    # 1. Calcolo Finanziario
    daily_saving = data.habit_cost * data.daily_quantity
    
    # Otteniamo il dizionario con le chiavi 'years_10', 'years_20', etc.
    projections = wealth_calc.generate_projections(daily_saving)
    
    # 2. Calcolo Salute
    health_analysis = health_calc.calculate_tdee(
        weight_kg=data.weight_kg, 
        height_cm=data.height_cm, 
        age=data.age, 
        gender=data.gender, 
        activity_level=data.activity_level,
        body_fat_percent=data.body_fat_percent, # Potrebbe essere None
        avg_daily_steps=data.avg_daily_steps    # Potrebbe essere None
    )
    
    health_impact = health_calc.calculate_health_impact(
        data.habit_name, data.daily_quantity
    )

    return {
        "user_analysis": health_analysis,
        "wealth_projection": {
            "daily_saving": round(daily_saving, 2),
            "annual_saving": round(daily_saving * 365, 2),
            # Le chiavi devono corrispondere a quelle in calculator.py
            "roi_10_years": projections['years_10'],
            "roi_30_years": projections['years_30']
        },
        "health_projection": health_impact
    }

# ENDPOINT 2: Solvibilità Quotidiana (Breve Termine - SDS)
@app.post("/calculate-solvency")
def calculate_solvency_endpoint(data: SolvencyInput):
    """
    Calcola quanto l'utente può spendere (Soldi) e consumare (Kcal) OGGI
    per rimanere in linea con i suoi obiettivi fino al prossimo stipendio.
    """
    return solvency_engine.calculate_metrics(data)