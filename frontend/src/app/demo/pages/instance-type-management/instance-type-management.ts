import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {NgbModal, NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { SharedModule } from 'src/app/theme/shared/shared.module';
import { Ec2Service } from 'src/app/theme/shared/service/ec2';

@Component({
  selector: 'app-instance-type-management',
  imports: [CommonModule, FormsModule, SharedModule, NgbModalModule ],
  templateUrl: './instance-type-management.html',
  styleUrls: ['./instance-type-management.scss']
})
export class InstanceTypeManagement implements OnInit {
 private ec2Service = inject(Ec2Service);
 private cdr = inject(ChangeDetectorRef);
 private modalService = inject(NgbModal);
  currentPage = 1;
  pageSize = 2;

 newInstanceType = {
  name: '',
  description: '',
  is_active: true
};


  instanceTypes: { id: number; name: string; description: string | null; is_active: boolean }[] = [];

  isLoading = false;
  isCreating = false;
  errorMessage = '';
  successMessage = '';

  ngOnInit(): void {
    this.loadInstanceTypes();
  }
  openAddTypeModal(content: unknown): void {
    this.errorMessage = '';
    this.successMessage = '';

    this.modalService.open(content, {
      centered: true,
      backdrop: 'static',
      size: 'md'
    });
  }

  loadInstanceTypes(): void {
    this.isLoading = true;
    this.errorMessage = '';

    this.ec2Service.getInstanceTypes().subscribe({
      next: (response) => {
        this.instanceTypes = response;
        this.currentPage = 1;
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.errorMessage = "Impossible de charger les types d'instance";
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  deleteInstanceType(id: number): void {
    if (!confirm("Voulez-vous vraiment supprimer ce type d'instance ?")) {
      return;
    }

    this.ec2Service.deleteInstanceType(id).subscribe({
      next: () => {
        this.successMessage = "Type d'instance supprime avec succes";
        this.loadInstanceTypes();
        this.cdr.detectChanges();
      },
      error: () => {
        this.errorMessage = "Erreur lors de la suppression";
        this.cdr.detectChanges();
      }
    });
  }

  toggleStatus(item: { id: number; is_active: boolean }): void {
    this.ec2Service.updateInstanceTypeStatus(item.id, !item.is_active).subscribe({
      next: () => {
        this.successMessage = "Statut mis a jour avec succes";
        this.loadInstanceTypes();
        this.cdr.detectChanges();
      },
      error: () => {
        this.errorMessage = "Erreur lors de la mise a jour du statut";
        this.cdr.detectChanges();
      }
    });
  }

  get totalPages(): number {
    return Math.ceil(this.instanceTypes.length / this.pageSize);
  }

  get pages(): number[] {
    return Array.from({ length: this.totalPages }, (_, index) => index + 1);
  }

  get paginatedInstanceTypes(): { id: number; name: string; description: string | null; is_active: boolean }[] {
    const startIndex = (this.currentPage - 1) * this.pageSize;
    return this.instanceTypes.slice(startIndex, startIndex + this.pageSize);
  }

  get resultsStart(): number {
    if (this.instanceTypes.length === 0) {
      return 0;
    }

    return (this.currentPage - 1) * this.pageSize + 1;
  }

  get resultsEnd(): number {
    return Math.min(this.currentPage * this.pageSize, this.instanceTypes.length);
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages) {
      return;
    }

    this.currentPage = page;
  }

 createInstanceType(modal?: { close: () => void }): void {
  this.errorMessage = '';
  this.successMessage = '';
  this.isCreating = true;

  this.ec2Service.createInstanceType({
    name: this.newInstanceType.name,
    description: this.newInstanceType.description,
    is_active: true
  }).subscribe({
    next: () => {
      this.successMessage = "Type d'instance ajoute avec succes";
      this.isCreating = false;

      this.newInstanceType = {
        name: '',
        description: '',
        is_active: true
      };

      modal?.close();
      this.loadInstanceTypes();
      this.cdr.detectChanges();
    },
    error: (error) => {
      this.errorMessage = error?.error?.detail || "Erreur lors de l'ajout du type d'instance";
      this.isCreating = false;
      this.cdr.detectChanges();
    }
  });
}


}
