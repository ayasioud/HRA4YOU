import { Injectable, inject, NgZone } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from './auth';

@Injectable({
  providedIn: 'root'
})
export class InactivityService {
  private router = inject(Router);
  private authService = inject(AuthService);
  private zone = inject(NgZone);

  private inactivityTime = 15 * 60 * 1000; 
  private warningTime = 30 * 1000;          
  private inactivityTimer: any;
  private warningTimer: any;

  showWarning = false;
  countdown = 30;
  private countdownInterval: any;

  // Référence fixe pour pouvoir supprimer l'écouteur
  private boundResetTimer = () => {
    if (!this.showWarning && this.authService.isLoggedIn()) {
      this.zone.run(() => this.resetTimer());
    }
  };

  startWatching(): void {
    if (!this.authService.isLoggedIn()) return;
    this.resetTimer();
    this.addEventListeners();
  }

  stopWatching(): void {
    this.clearTimers();
    this.removeEventListeners();
  }

  resetTimer(): void {
    this.clearTimers();
    this.showWarning = false;
    this.countdown = 30;

    this.zone.runOutsideAngular(() => {
      this.inactivityTimer = setTimeout(() => {
        this.zone.run(() => {
          this.showWarningPopup();
        });
      }, this.inactivityTime);
    });
  }

  private showWarningPopup(): void {
    if (!this.authService.isLoggedIn()) return;
    this.zone.run(() => {
      this.showWarning = true;
      this.countdown = 30;

      this.countdownInterval = setInterval(() => {
        this.zone.run(() => {
          this.countdown--;
          if (this.countdown <= 0) {
            this.logout();
          }
        });
      }, 1000);

      this.warningTimer = setTimeout(() => {
        this.logout();
      }, this.warningTime);
    });
  }

  stayConnected(): void {
    this.clearTimers();
    this.showWarning = false;
    this.countdown = 30;
    this.resetTimer();
  }

  forceLogout(): void {
    this.clearTimers();
    this.showWarning = false;
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  private logout(): void {
    this.clearTimers();
    this.showWarning = false;
    this.authService.logout();
    this.router.navigate(['/login'], {
      queryParams: { message: 'Session expirée par inactivité' }
    });
  }

  private addEventListeners(): void {
    const events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];
    events.forEach(event => {
      window.addEventListener(event, this.boundResetTimer);
    });
  }

  private removeEventListeners(): void {
    const events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];
    events.forEach(event => {
      window.removeEventListener(event, this.boundResetTimer);
    });
  }

  private clearTimers(): void {
    if (this.inactivityTimer) clearTimeout(this.inactivityTimer);
    if (this.warningTimer) clearTimeout(this.warningTimer);
    if (this.countdownInterval) clearInterval(this.countdownInterval);
  }
}