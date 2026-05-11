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

interface InstanceSshPortResponse {
  instance_name: string;
  ssh_port: number;
  ssh_command: string;
}
interface Ec2Image {
  image_id: string;
  name: string;
  description: string;
  creation_date: string;
}
interface InstanceTypeItem {
  id: number;
  name: string;
  description: string | null;
  is_active: boolean;
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

  getInstanceSshPort(instanceName: string): Observable<InstanceSshPortResponse> {
    const token = this.authService.getToken();

    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`
    });

    return this.http.get<InstanceSshPortResponse>(
      `${this.apiUrl}/ec2/${encodeURIComponent(instanceName)}/ssh-port`,
      { headers }
    );
  }

  getImages(): Observable<Ec2Image[]> {
  const token = this.authService.getToken();

  const headers = new HttpHeaders({
    Authorization: `Bearer ${token}`
  });

  return this.http.get<Ec2Image[]>(
    `${this.apiUrl}/ec2/images`,
    { headers }
  );
  
}
getInstanceTypes(): Observable<InstanceTypeItem[]> {
  const token = this.authService.getToken();

  const headers = new HttpHeaders({
    Authorization: `Bearer ${token}`
  });

  return this.http.get<InstanceTypeItem[]>(
    `${this.apiUrl}/instance-types/`,
    { headers }
  );
}
deleteInstanceType(id: number): Observable<void> {
  const token = this.authService.getToken();

  const headers = new HttpHeaders({
    Authorization: `Bearer ${token}`
  });

  return this.http.delete<void>(
    `${this.apiUrl}/instance-types/${id}`,
    { headers }
  );
}

updateInstanceTypeStatus(id: number, is_active: boolean): Observable<any> {
  const token = this.authService.getToken();

  const headers = new HttpHeaders({
    Authorization: `Bearer ${token}`
  });

  return this.http.patch(
    `${this.apiUrl}/instance-types/${id}/status`,
    { is_active },
    { headers }
  );
}
createInstanceType(payload: { name: string; description: string | null; is_active: boolean }): Observable<any> {
  const token = this.authService.getToken();

  const headers = new HttpHeaders({
    Authorization: `Bearer ${token}`
  });

  return this.http.post(
    `${this.apiUrl}/instance-types/`,
    payload,
    { headers }
  );
}





}
