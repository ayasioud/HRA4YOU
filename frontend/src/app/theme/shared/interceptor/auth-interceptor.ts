import { Injectable, inject } from '@angular/core';
import {
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpInterceptor,
  HttpErrorResponse
} from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Router } from '@angular/router';
import { AuthService } from '../service/auth';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  private authService = inject(AuthService);
  private router = inject(Router);

  intercept(request: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    

    const token = this.authService.getToken();
    
    if (token) {
      // Vérifie si le token est expiré
      if (this.isTokenExpired(token)) {
        this.authService.logout();
        this.router.navigate(['/login'], {
          queryParams: { message: 'Session expirée, reconnectez-vous' }
        });
        return throwError(() => new Error('Token expiré'));
      }


      request = request.clone({
        setHeaders: {
          Authorization: `Bearer ${token}`
        }
      });
    }


    return next.handle(request).pipe(
      catchError((error: HttpErrorResponse) => {
        if (error.status === 401) {
          this.authService.logout();
          this.router.navigate(['/login'], {
            queryParams: { message: 'Session expirée, reconnectez-vous' }
          });
        }
        return throwError(() => error);
      })
    );
  }

  private isTokenExpired(token: string): boolean {
    try {

      const payload = JSON.parse(atob(token.split('.')[1]));
      const expiration = payload.exp * 1000; // Convertir en millisecondes
      return Date.now() > expiration;
    } catch {
      return true; 
    }
  }
}