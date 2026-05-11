import { ChangeDetectorRef, Component, inject, ViewChild, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, NgForm } from '@angular/forms';

import { SharedModule } from 'src/app/theme/shared/shared.module';
import { Ec2Service } from 'src/app/theme/shared/service/ec2';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';

@Component({
  selector: 'app-instance-create',
  imports: [CommonModule, FormsModule, SharedModule, NgbDropdownModule],
  templateUrl: './instance-create.html',
  styleUrls: ['./instance-create.scss']
})
export class InstanceCreateComponent implements OnInit {
  @ViewChild('instanceForm') instanceForm!: NgForm;

  private ec2Service = inject(Ec2Service);
  private cdr = inject(ChangeDetectorRef);

  // ── Data ──────────────────────────────────────────────────────────────────
  images: { image_id: string; name: string; description: string; creation_date: string }[] = [];
  instanceTypes: { id: number; name: string; description: string | null; is_active: boolean }[] = [];

  // ── Loading states ────────────────────────────────────────────────────────
  isLoadingImages = false;
  isLoadingInstanceTypes = false;
  isLoading = false;

  // ── Dropdown labels ───────────────────────────────────────────────────────
  selectedImageLabel = 'Selectionner une image';

  // ── Form ──────────────────────────────────────────────────────────────────
  formData = {
    instance_name: '',
    image_id: '',
    instance_type: '',
    storage_size: 100,
    created_by: '',
    owner_agency: ''
  };

  // ── Messages ──────────────────────────────────────────────────────────────
  errorMessage = '';
  successMessage = '';
  sshPortMessage = '';
  sshCommandMessage = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  ngOnInit(): void {
    this.loadImages();
    this.loadInstanceTypes();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────
  loadImages(): void {
    this.isLoadingImages = true;
    this.ec2Service.getImages().subscribe({
      next: (response) => {
        this.images = response;
        this.isLoadingImages = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.errorMessage = 'Impossible de charger les images AWS';
        this.isLoadingImages = false;
        this.cdr.detectChanges();
      }
    });
  }

  loadInstanceTypes(): void {
    this.isLoadingInstanceTypes = true;
    this.ec2Service.getInstanceTypes().subscribe({
      next: (response) => {
        this.instanceTypes = response.filter((item) => item.is_active);
        this.isLoadingInstanceTypes = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.errorMessage = "Impossible de charger les types d'instance";
        this.isLoadingInstanceTypes = false;
        this.cdr.detectChanges();
      }
    });
  }

  // ── Dropdown selectors ────────────────────────────────────────────────────
  selectImage(imageId: string, imageName: string): void {
    this.formData.image_id = imageId;
    this.selectedImageLabel = imageName;
  }

  selectInstanceType(typeName: string): void {
    this.formData.instance_type = typeName;
  }

  get selectedInstanceTypeLabel(): string {
    return this.formData.instance_type || 'Selectionner un type';
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  onCreateInstance(): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.sshPortMessage = '';
    this.sshCommandMessage = '';
    this.isLoading = true;

    this.ec2Service.createInstance(this.formData).subscribe({
      next: (response) => {
        const createdInstanceName = response.instance_name || this.formData.instance_name;
        this.successMessage = response.message;
        this.ec2Service.getInstanceSshPort(createdInstanceName).subscribe({
          next: (sshInfo) => {
            this.sshPortMessage = `Port SSH pour ${sshInfo.instance_name}: ${sshInfo.ssh_port}`;
            this.sshCommandMessage = sshInfo.ssh_command;
            this.isLoading = false;
            this.resetForm();
            this.cdr.detectChanges();
          },
          error: () => {
            this.sshPortMessage =
              `Instance creee (${createdInstanceName}), mais le port SSH n'est pas encore disponible.`;
            this.sshCommandMessage = '';
            this.isLoading = false;
            this.resetForm();
            this.cdr.detectChanges();
          }
        });
      },
      error: (error) => {
        this.errorMessage = JSON.stringify(
          error?.error?.detail ?? error?.error ?? "Erreur lors de la création de l'instance",
          null,
          2
        );
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  private resetForm(): void {
    this.instanceForm.resetForm({
      instance_name: '',
      image_id: '',
      instance_type: '',
      storage_size: 100,
      created_by: '',
      owner_agency: ''
    });
    // Réinitialiser les labels des dropdowns
    this.selectedImageLabel = 'Selectionner une image';
  }
}