import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'dart:io' show Platform;

class BioSyncService {
  // Istanza Singleton del plugin Health
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
      // 1. CONFIGURAZIONE INIZIALE (Specifica per v10+)
      // Importante per abilitare Health Connect su Android
      await _health.configure();

      // 2. RICHIESTA PERMESSI
      // Su Android chiediamo Activity Recognition
      if (Platform.isAndroid) {
        await Permission.activityRecognition.request();
      }
      
      // Richiediamo autorizzazione per i tipi specifici
      // Nota: in Health v13 non serve più specificare i permessi (READ/WRITE) se sono di default
      bool requested = await _health.requestAuthorization(_types);

      if (!requested) {
        print("Permessi Salute negati o non concessi.");
        return false;
      }

      // 3. LETTURA DATI (Ultimi 30 giorni)
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));

      // Fetch del Peso
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT], 
        startTime: start, 
        endTime: now,
      );
      
      // Pulizia dati: Rimuoviamo duplicati
      healthData = _health.removeDuplicates(healthData);

      if (healthData.isNotEmpty) {
        // Ordiniamo per data (dal più recente)
        healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        
        // Estrazione valore
        var latestPoint = healthData.first;
        double weightVal = 0.0;

        // Estrazione sicura del numero (NumericHealthValue è lo standard in v13)
        if (latestPoint.value is NumericHealthValue) {
           weightVal = (latestPoint.value as NumericHealthValue).numericValue.toDouble();
        }

        print("Peso rilevato da Health Connect: $weightVal Kg");

        // 4. UPLOAD SU SUPABASE (Trigger SQL farà il resto)
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && weightVal > 0) {
          await Supabase.instance.client.from('profiles').update({
            'weight_kg': weightVal,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);
          
          return true; // Successo
        }
      } else {
        print("Nessun dato sul peso trovato negli ultimi 30 giorni.");
      }
    } catch (e) {
      print("Errore Sync Salute: $e");
    }
    return false;
  }
}