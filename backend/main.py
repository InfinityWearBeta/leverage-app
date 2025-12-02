from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
from pydantic import BaseModel

# Importa i modelli dal file core
from core.solvency_core import SolvencyManager, UserProfile, Expense, DailyLog

app = FastAPI(title="Leverage API 8.1")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class RequestPayload(BaseModel):
    profile: UserProfile
    expenses: List[Expense]
    logs: List[DailyLog]

@app.post("/calculate-bio-solvency")
def calculate_state(payload: RequestPayload):
    try:
        manager = SolvencyManager(payload.profile, payload.expenses, payload.logs)
        return manager.calculate_bio_financial_state()
    except Exception as e:
        print(f"Server Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))