enum AppRole { client, admin, barber, manager }

/// Mapea los roles de la app a los IDs de rol de la API.
/// 1 = Gerente (Super Adm), 18 = Administrador, 2 = barbero, 3 = cliente
int rolIdForRole(AppRole role) {
  switch (role) {
    case AppRole.manager:
      return 1;
    case AppRole.admin:
      return 18;
    case AppRole.barber:
      return 2;
    case AppRole.client:
      return 3;
  }
}

/// Devuelve el rol de la app correspondiente a un rolId. Retorna null si no existe.
AppRole? roleForRolId(int? rolId) {
  switch (rolId) {
    case 1:
      return AppRole.manager;
    case 18:
      return AppRole.admin;
    case 2:
      return AppRole.barber;
    case 3:
      return AppRole.client;
    default:
      return null;
  }
}

String roleLabel(AppRole role) {
  switch (role) {
    case AppRole.manager:
      return 'Gerente';
    case AppRole.admin:
      return 'Administrador';
    case AppRole.barber:
      return 'Barbero';
    case AppRole.client:
      return 'Cliente';
  }
}

String roleLabelFromRolId(int? rolId) {
  final role = roleForRolId(rolId);
  if (role == null) return 'Rol desconocido';
  return roleLabel(role);
}

