import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart'; // Importante per Android

class BioSyncService {
  // Configurazione del plugin Health
  final Health _health = Health();

  // Tipi di dati che vogliamo leggere
  final List<HealthDataType> _types = [
    HealthDataType.WEIGHT,
    HealthDataType.STEPS,
    HealthDataType.HEIGHT,
  ];

  /// Core: Sincronizza il Peso e aggiorna Supabase
  Future<bool> syncBiometrics() async {
    try {
      // 1. RICHIESTA PERMESSI
      // Su Android è buona prassi chiedere prima Activity Recognition
      await Permission.activityRecognition.request();
      
      // Poi chiediamo Health Connect
      bool requested = await _health.requestAuthorization(_types);

      if (!requested) {
        print("Permessi Salute negati.");
        return false;
      }

      // 2. LETTURA DATI (Ultimi 30 giorni)
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));

      // Fetch del Peso
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT], 
        startTime: start, 
        endTime: now
      );
      
      // Pulizia dati: Rimuoviamo duplicati
      healthData = _health.removeDuplicates(healthData);

      if (healthData.isNotEmpty) {
        // Ordiniamo per data (dal più recente)
        healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        
        // Estrazione valore (il plugin restituisce NumericHealthValue)
        var latestValue = healthData.first.value;
        double weightVal = 0.0;

        // Estrazione sicura del numero
        if (latestValue is NumericHealthValue) {
           weightVal = latestValue.numericValue.toDouble();
        }

        print("Peso rilevato da Health: $weightVal Kg");

        // 3. UPLOAD SU SUPABASE (Trigger SQL farà il resto)
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && weightVal > 0) {
          await Supabase.instance.client.from('profiles').update({
            'weight_kg': weightVal,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
          
          return true; // Successo
        }
      }
    } catch (e) {
      print("Errore Sync Salute: $e");
    }
    return false;
  }
}