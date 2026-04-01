import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/app_role.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final AppRole role;
  
  const AuthAuthenticated(this.role);

  @override
  List<Object?> get props => [role];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
