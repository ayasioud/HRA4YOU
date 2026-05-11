import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from 'src/app/theme/shared/service/auth';

@Component({
  selector: 'app-auth-signin',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './auth-signin.component.html',
  styleUrls: ['./auth-signin.component.scss']
})
export class AuthSigninComponent {
  private authService = inject(AuthService);
  private router = inject(Router);

  username = '';
  password = '';
  errorMessage = '';
  isLoading = false;
  isCrowdLoading = false;

  onLoginWithCrowd(): void {
    this.isCrowdLoading = true;
    this.authService.loginWithCrowd();
  }

  onLogin(): void {
    this.errorMessage = '';
    this.isLoading = true;

    this.authService.login({
      username: this.username,
      password: this.password
    }).subscribe({
      next: (response) => {
        this.authService.saveToken(response.access_token);
        this.authService.saveUsername(this.username);
        this.router.navigate(['/dashboard']);
      },
      error: () => {
        this.errorMessage = 'Identifiants invalides';
        this.isLoading = false;
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }
}