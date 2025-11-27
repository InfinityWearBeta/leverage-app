from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware # <--- NUOVO IMPORT
from pydantic import BaseModel
from core.calculator import WealthCalculator

# 1. Configurazione
app = FastAPI(
    title="LEVERAGE API",
    description="Backend per il calcolo dell'interesse composto",
    version="1.0.0"
)

# --- CONFIGURAZIONE CORS (NUOVO BLOCCO) ---
# Permette al Frontend (che gira su una porta diversa) di parlare col Backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # "*" significa "accetta tutti". In produzione metteremo l'URL specifico.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# -------------------------------------------

wealth_calc = WealthCalculator(interest_rate=0.07)

class LeverageInput(BaseModel):
    benchmark_cost: float
    module_cost: float

@app.get("/")
def read_root():
    return {"status": "online", "message": "LEVERAGE API è pronta."}

@app.post("/calculate")
def calculate_leverage(data: LeverageInput):
    daily_saving = data.benchmark_cost - data.module_cost

    if daily_saving <= 0:
        return {
            "success": False,
            "message": "Il Modulo deve costare meno del Benchmark!"
        }

    projections = wealth_calc.generate_projections(daily_saving)

    return {
        "success": True,
        "input_data": {
            "benchmark": data.benchmark_cost,
            "module": data.module_cost
        },
        "analysis": {
            "daily_saving": round(daily_saving, 2),
            "roi_projections": projections
        }
    }