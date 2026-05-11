import { ComponentFixture, TestBed } from '@angular/core/testing';

import { InactivityWarning } from './inactivity-warning';

describe('InactivityWarning', () => {
  let component: InactivityWarning;
  let fixture: ComponentFixture<InactivityWarning>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [InactivityWarning]
    })
    .compileComponents();

    fixture = TestBed.createComponent(InactivityWarning);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
