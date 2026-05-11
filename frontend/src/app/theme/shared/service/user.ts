import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

import { AuthService } from './auth';

export interface AppUser {
  id: number;
  username: string;
  email: string | null;
  role: string;
  is_active: boolean;
  created_at: string;
}

export interface CreateUserPayload {
  username: string;
  email: string | null;
  password: string;
  role: string;
  is_active: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class UserService {
  private http = inject(HttpClient);
  private authService = inject(AuthService);
  private apiUrl = 'http://127.0.0.1:8000';

  private getHeaders(): HttpHeaders {
    const token = this.authService.getToken();

    return new HttpHeaders({
      Authorization: `Bearer ${token}`
    });
  }

  getUsers(): Observable<AppUser[]> {
    return this.http.get<AppUser[]>(`${this.apiUrl}/users/`, {
      headers: this.getHeaders()
    });
  }

  createUser(payload: CreateUserPayload): Observable<AppUser> {
    return this.http.post<AppUser>(`${this.apiUrl}/users/`, payload, {
      headers: this.getHeaders()
    });
  }
}
