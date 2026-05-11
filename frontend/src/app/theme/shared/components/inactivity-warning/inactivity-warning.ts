import { Component, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { InactivityService } from '../../service/inactivity';

@Component({
  selector: 'app-inactivity-warning',
  standalone: true,
  imports: [CommonModule],
  changeDetection: ChangeDetectionStrategy.Default,
  template: `
    <div *ngIf="inactivityService.showWarning" class="inactivity-overlay">
      <div class="inactivity-popup">
        
        <div class="popup-icon">⏰</div>
        
        <h4>Session inactive</h4>
        
        <p>Votre session va expirer dans</p>
        
        <div class="countdown">
          {{ inactivityService.countdown }}
        </div>
        
        <p class="text-muted">secondes</p>
        
        <button 
          class="btn btn-primary w-100 mt-3"
          (click)="stayConnected()">
          Rester connecté
        </button>

        <button 
          class="btn btn-outline-secondary w-100 mt-2"
          (click)="logout()">
          Se déconnecter
        </button>

      </div>
    </div>
  `,
  styles: [`
    .inactivity-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.6);
      z-index: 9999;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .inactivity-popup {
      background: white;
      border-radius: 12px;
      padding: 32px;
      width: 340px;
      text-align: center;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    }

    .popup-icon {
      font-size: 48px;
      margin-bottom: 16px;
    }

    .countdown {
      font-size: 56px;
      font-weight: bold;
      color: #f44336;
      margin: 8px 0;
    }
  `]
})
export class InactivityWarningComponent {
  inactivityService = inject(InactivityService);
  private cdr = inject(ChangeDetectorRef);

  constructor() {
    // Force la détection de changement toutes les secondes
    setInterval(() => {
      this.cdr.detectChanges();
    }, 500);
  }

  stayConnected(): void {
    this.inactivityService.stayConnected();
    this.cdr.detectChanges();
  }

  logout(): void {
    this.inactivityService.forceLogout();
    this.cdr.detectChanges();
  }
}