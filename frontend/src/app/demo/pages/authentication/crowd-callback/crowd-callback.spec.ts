import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CrowdCallback } from './crowd-callback';

describe('CrowdCallback', () => {
  let component: CrowdCallback;
  let fixture: ComponentFixture<CrowdCallback>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CrowdCallback]
    })
    .compileComponents();

    fixture = TestBed.createComponent(CrowdCallback);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
