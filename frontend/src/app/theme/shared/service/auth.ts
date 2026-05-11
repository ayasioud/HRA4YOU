import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

interface LoginPayload {
  username: string;
  password: string;
}

interface LoginResponse {
  access_token: string;
  token_type: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private http = inject(HttpClient);
  private apiUrl = 'http://127.0.0.1:8000';

  // ── Login classique ───────────────────────────────────────────
  login(payload: LoginPayload): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.apiUrl}/auth/login`, payload);
  }

  // ── SSO Crowd ─────────────────────────────────────────────────
  loginWithCrowd(): void {
    window.location.href = `${this.apiUrl}/auth/crowd/login`;
  }

  extractTokenFromFragment(): string | null {
    const fragment = window.location.hash;
    if (!fragment) return null;
    const params = new URLSearchParams(fragment.replace('#', ''));
    return params.get('token');
  }

  // ── Gestion du token ──────────────────────────────────────────
  saveToken(token: string): void {
    localStorage.setItem('access_token', token);
  }

  getToken(): string | null {
    return localStorage.getItem('access_token');
  }

  logout(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('username');
  }

  isLoggedIn(): boolean {
    return !!this.getToken();
  }

  saveUsername(username: string): void {
    localStorage.setItem('username', username);
  }

  getUsername(): string {
    return localStorage.getItem('username') || 'Admin';
  }
}