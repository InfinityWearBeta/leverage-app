class WealthCalculator:
    """
    Gestisce la logica finanziaria dell'applicazione.
    Calcola l'interesse composto basato su risparmi giornalieri ricorrenti.
    """

    def __init__(self, interest_rate: float = 0.07):
        # Tasso di interesse standard del mercato azionario (S&P 500 storico ~7-10%)
        # 0.07 corrisponde al 7%
        self.annual_rate = interest_rate

    def calculate_compound_interest(self, daily_saving: float, years: int) -> float:
        """
        Calcola il valore futuro di un risparmio GIORNALIERO investito per X anni.
        Formula della rendita (Annuity): FV = P * (((1 + r)^n - 1) / r)
        """
        
        # 1. Convertiamo il risparmio giornaliero in contributo annuale
        # Assumiamo 365 giorni. Es: 10€ al giorno = 3650€ l'anno.
        annual_contribution = daily_saving * 365

        # 2. Applichiamo la formula dell'interesse composto per una serie di pagamenti
        # FV = Future Value
        # P = Pagamento Annuale
        # r = Tasso interesse (0.07)
        # n = Numero di anni
        
        if self.annual_rate == 0:
            return annual_contribution * years

        future_value = annual_contribution * (((1 + self.annual_rate) ** years - 1) / self.annual_rate)

        return round(future_value, 2)

    def generate_projections(self, daily_saving: float):
        """
        Genera una proiezione completa su 10, 20 e 30 anni.
        """
        return {
            "daily_saving": daily_saving,
            "10_years": self.calculate_compound_interest(daily_saving, 10),
            "20_years": self.calculate_compound_interest(daily_saving, 20),
            "30_years": self.calculate_compound_interest(daily_saving, 30),
        }