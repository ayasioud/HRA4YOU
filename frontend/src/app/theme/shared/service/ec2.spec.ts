import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

import { AuthService } from './auth';

interface CreateInstancePayload {
  instance_name: string;
  image_id: string;
  instance_type: string;
  storage_size: number;
  created_by: string;
  owner_agency: string;
}

interface CreateInstanceResponse {
  status: string;
  message: string;
  instance_name: string;
  terraform_enabled: boolean;
  stdout: string | null;
  stderr: string | null;
}

@Injectable({
  providedIn: 'root'
})
export class Ec2Service {
  private http = inject(HttpClient);
  private authService = inject(AuthService);
  private apiUrl = 'http://127.0.0.1:8000';

  createInstance(payload: CreateInstancePayload): Observable<CreateInstanceResponse> {
    const token = this.authService.getToken();

    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`
    });

    return this.http.post<CreateInstanceResponse>(
      `${this.apiUrl}/ec2/create`,
      payload,
      { headers }
    );
  }
}
