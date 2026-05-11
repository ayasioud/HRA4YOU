import { Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from 'src/app/theme/shared/service/auth';

@Component({
  selector: 'app-crowd-callback',
  standalone: true,
  imports: [],
  templateUrl: './crowd-callback.html',
  styleUrl: './crowd-callback.scss',
})
export class CrowdCallback implements OnInit {
  private authService = inject(AuthService);
  private router = inject(Router);

  errorMessage = '';

  ngOnInit(): void {
    const token = this.authService.extractTokenFromFragment();

    if (token) {
      this.authService.saveToken(token);
      this.router.navigate(['/dashboard']);
    } else {
      this.errorMessage = 'Erreur de connexion Crowd. Veuillez réessayer.';
      setTimeout(() => this.router.navigate(['/login']), 3000);
    }
  }
}