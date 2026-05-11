import { TestBed } from '@angular/core/testing';

import { Inactivity } from './inactivity';

describe('Inactivity', () => {
  let service: Inactivity;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Inactivity);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
