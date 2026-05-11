import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';

import { NgbDropdownConfig } from '@ng-bootstrap/ng-bootstrap';

import { SharedModule } from 'src/app/theme/shared/shared.module';
import { AuthService } from 'src/app/theme/shared/service/auth';

@Component({
  selector: 'app-nav-right',
  imports: [SharedModule],
  templateUrl: './nav-right.component.html',
  styleUrls: ['./nav-right.component.scss'],
  providers: [NgbDropdownConfig]
})
export class NavRightComponent {
  private authService = inject(AuthService);
  private router = inject(Router);

  username = this.authService.getUsername();

  constructor() {
    const config = inject(NgbDropdownConfig);
    config.placement = 'bottom-right';
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}
