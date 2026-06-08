// Colombia (America/Bogota) is always UTC-5 (no DST).
DateTime nowColombia() => DateTime.now().toUtc().subtract(const Duration(hours: 5));
