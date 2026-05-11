import { ChangeDetectorRef, Component, inject, OnInit, ViewChild } from '@angular/core';

import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';
import { NgbModal, NgbModalModule } from '@ng-bootstrap/ng-bootstrap';



import { SharedModule } from 'src/app/theme/shared/shared.module';
import { AppUser, UserService } from 'src/app/theme/shared/service/user';



@Component({
  selector: 'app-user-management',
  imports: [CommonModule, FormsModule, SharedModule, NgbModalModule],
  templateUrl: './user-management.html',
  styleUrls: ['./user-management.scss']
})
export class UserManagementComponent implements OnInit {
  private modalService = inject(NgbModal);
  private userService = inject(UserService);
  private cdr = inject(ChangeDetectorRef);
  @ViewChild('userForm') userForm!: NgForm;

currentPage = 1;
pageSize = 2;


  users: AppUser[] = [];

  isLoading = false;
  isCreating = false;
  errorMessage = '';
  successMessage = '';

  newUser = {
    username: '',
    email: '',
    password: '',
    role: 'admin',
    is_active: true
  };

  ngOnInit(): void {
    this.loadUsers();
  }

  loadUsers(): void {
    this.isLoading = true;
    this.errorMessage = '';

    this.userService.getUsers().subscribe({
      next: (response) => {
        this.users = response;
        this.currentPage = 1;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (error) => {
        this.errorMessage = JSON.stringify(
          error?.error?.detail ?? error?.error ?? 'Impossible de charger les utilisateurs',
          null,
          2
        );
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  createUser(modal?: { close: () => void }): void {
  this.isCreating = true;
  this.errorMessage = '';
  this.successMessage = '';

  this.userService.createUser({
    username: this.newUser.username,
    email: this.newUser.email || null,
    password: this.newUser.password,
    role: this.newUser.role,
    is_active: true
  }).subscribe({
    next: () => {
      this.successMessage = 'Utilisateur cree avec succes';
      this.isCreating = false;

      this.newUser = {
        username: '',
        email: '',
        password: '',
        role: 'admin',
        is_active: true
      };

      modal?.close();
      this.loadUsers();
      this.cdr.detectChanges();
    },

    error: (error) => {
      this.errorMessage = JSON.stringify(
        error?.error?.detail ?? error?.error ?? "Erreur lors de la creation de l'utilisateur",
        null,
        2
      );
      this.isCreating = false;
      this.cdr.detectChanges();
    }
  });
}

  passwordContainsUserData(): boolean {
  const password = (this.newUser.password || '').toLowerCase().trim();
  const username = (this.newUser.username || '').toLowerCase().trim();
  const email = (this.newUser.email || '').toLowerCase().trim();
  const emailName = email.includes('@') ? email.split('@')[0] : email;

  if (!password) {
    return false;
  }

  if (username.length >= 3 && password.includes(username)) {
    return true;
  }

  if (email.length >= 3 && password.includes(email)) {
    return true;
  }

  if (emailName.length >= 3 && password.includes(emailName)) {
    return true;
  }

  return false;
}


get totalPages(): number {
  return Math.ceil(this.users.length / this.pageSize);
}

get pages(): number[] {
  return Array.from({ length: this.totalPages }, (_, index) => index + 1);
}

get paginatedUsers(): AppUser[] {
  const startIndex = (this.currentPage - 1) * this.pageSize;
  return this.users.slice(startIndex, startIndex + this.pageSize);
}

goToPage(page: number): void {
  if (page < 1 || page > this.totalPages) {
    return;
  }

  this.currentPage = page;
}
openAddUserModal(content: unknown): void {
  this.errorMessage = '';
  this.successMessage = '';

  this.modalService.open(content, {
    centered: true,
    backdrop: 'static',
    size: 'lg'
  });
}



}
