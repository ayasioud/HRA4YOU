import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { SharedModule } from 'src/app/theme/shared/shared.module';
import { Ec2Service } from 'src/app/theme/shared/service/ec2';


@Component({
  selector: 'app-instance-create',
  imports: [CommonModule, FormsModule, SharedModule],
  templateUrl: './instance-create.component.html',
  styleUrls: ['./instance-create.component.scss']
})
export class InstanceCreateComponent {
  private ec2Service = inject(Ec2Service);

  formData = {
    instance_name: '',
    image_id: '',
    instance_type: '',
    storage_size: 100,
    created_by: '',
    owner_agency: ''
  };

  isLoading = false;
  errorMessage = '';
  successMessage = '';
  apiResponse: string | null = null;

  onCreateInstance(): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.apiResponse = null;
    this.isLoading = true;

    this.ec2Service.createInstance(this.formData).subscribe({
      next: (response) => {
        this.successMessage = response.message;
        this.apiResponse = JSON.stringify(response, null, 2);
      },
      error: (error) => {
        this.errorMessage = error?.error?.detail || 'Erreur lors de la creation de l’instance';
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }
}
