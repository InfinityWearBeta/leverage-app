from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional 
from core.calculator import WealthCalculator
from core.health import HealthCalculator

app = FastAPI(title="LEVERAGE API 2.1 - Hybrid")

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

# Il Contratto Dati
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

@app.get("/")
def read_root():
    return {"status": "online", "version": "2.1 Hybrid Fixed"}

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
            # Qui cerchiamo le chiavi corrette definite in calculator.py
            "roi_10_years": projections['years_10'],
            "roi_30_years": projections['years_30']
        },
        "health_projection": health_impact
    }