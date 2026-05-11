import { Component, OnInit, OnDestroy, inject } from '@angular/core';
import { NavigationEnd, Router, RouterModule } from '@angular/router';
import { CommonModule } from '@angular/common';

import { SpinnerComponent } from './theme/shared/components/spinner/spinner.component';
import { InactivityWarningComponent } from './theme/shared/components/inactivity-warning/inactivity-warning';
import { InactivityService } from './theme/shared/service/inactivity';
import { AuthService } from './theme/shared/service/auth';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [SpinnerComponent, RouterModule, CommonModule, InactivityWarningComponent],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit, OnDestroy {
  private router = inject(Router);
  private inactivityService = inject(InactivityService);
  private authService = inject(AuthService);

  title = 'datta-able';

  ngOnInit() {
    this.router.events.subscribe((evt) => {
      if (!(evt instanceof NavigationEnd)) {
        return;
      }
      window.scrollTo(0, 0);

      // Démarre la surveillance seulement si connecté
      if (this.authService.isLoggedIn()) {
        this.inactivityService.startWatching();
      } else {
        this.inactivityService.stopWatching();
      }
    });
  }

  ngOnDestroy() {
    this.inactivityService.stopWatching();
  }
}