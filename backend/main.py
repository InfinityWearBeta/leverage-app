from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional

# Importiamo il nuovo motore logico avanzato e i suoi modelli dati
# Assicurati che il file 'backend/core/solvency_core.py' esista
from core.solvency_core import SolvencyManager, UserProfile, Expense, DailyLog

app = FastAPI(title="LEVERAGE API 8.0 - Bio-Financial God Mode")

# --- CONFIGURAZIONE CORS ---
# Permette all'app Flutter (Web e Mobile) di comunicare con il server senza blocchi
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MODELLO DI RICHIESTA (WRAPPER) ---
# Questo modello definisce la struttura esatta del JSON che Flutter deve inviare.
# Raggruppa i tre pilastri: Profilo Utente, Spese Fisse, Diario Giornaliero.
class BioSolvencyRequest(BaseModel):
    profile: UserProfile
    expenses: List[Expense]
    logs: List[DailyLog]

# --- ENDPOINTS ---

@app.get("/")
def read_root():
    """Health Check: Verifica se il server è vivo."""
    return {
        "status": "online", 
        "version": "8.0 Bio-Financial Active",
        "engine": "SolvencyManager v1.0"
    }

@app.post("/calculate-bio-solvency")
def calculate_bio_financial_state_endpoint(data: BioSolvencyRequest):
    """
    ENDPOINT PRINCIPALE (Il Cervello).
    
    Input: Stato completo dell'utente (Profilo, Spese, Log).
    Output: JSON con 3 sezioni (Financial, Biological, Psychology).
    
    Logica:
    1. Riceve i dati e li valida automaticamente grazie a Pydantic.
    2. Istanzia il SolvencyManager.
    3. Esegue i calcoli complessi (SDS, SDC, Sugar Tax, Negotiation).
    4. Restituisce il risultato strutturato.
    """
    try:
        # 1. Istanziamo il Manager iniettando i dati ricevuti
        manager = SolvencyManager(
            profile=data.profile,
            expenses=data.expenses,
            logs=data.logs
        )
        
        # 2. Eseguiamo il calcolo
        # Questo metodo contiene tutta la logica "God Mode" (Date, Windfall, Tasse)
        result = manager.calculate_bio_financial_state()
        
        return result

    except Exception as e:
        # Gestione robusta degli errori: se il motore fallisce, non crashare silenziosamente
        # ma restituisci un errore 500 con i dettagli per il debug.
        error_msg = f"Calculation Engine Failure: {str(e)}"
        print(f"❌ ERRORE CRITICO: {error_msg}") # Log visibile nella console di Render
        raise HTTPException(status_code=500, detail=error_msg)

# Nota: I vecchi endpoint (es. /calculate-projection) sono stati rimossi 
# per mantenere l'architettura pulita e forzare l'uso del nuovo standard v8.0.