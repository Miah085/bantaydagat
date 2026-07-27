export const SENSOR_THRESHOLDS = {
  airTemp: { safe: [25.00, 32.00], caution: [22.00, 35.00] },
  waterTemp: { safe: [26.00, 31.00], caution: [24.00, 33.00] },
  humidity: { safe: [65.00, 85.00], caution: [55.00, 90.00] },
  ph: { safe: [7.80, 8.30], caution: [7.50, 8.50] },
  turbidity: { safe: [0.00, 8.00], caution: [0.00, 15.00] }
};

export function evaluateParameter(value, key) {
  if (key === 'turbidity') {
    if (value > 15.00) return 'DANGER';
    if (value > 8.00) return 'CAUTION';
    return 'SAFE';
  }

  const { safe, caution } = SENSOR_THRESHOLDS[key];
  if (value < caution[0] || value > caution[1]) return 'DANGER';
  if (value >= safe[0] && value <= safe[1]) return 'SAFE';
  return 'CAUTION';
}

export function getSystemDecision(air, water, hum, ph, turb) {
  const statuses = [
    evaluateParameter(air, 'airTemp'),
    evaluateParameter(water, 'waterTemp'),
    evaluateParameter(hum, 'humidity'),
    evaluateParameter(ph, 'ph'),
    evaluateParameter(turb, 'turbidity')
  ];

  const cautionCount = statuses.filter(s => s === 'CAUTION').length;
  const dangerCount = statuses.filter(s => s === 'DANGER').length;

  if (dangerCount >= 1) return { status: 'NO-GO: DO NOT RELEASE (DANGER)', type: 'danger' };
  if (cautionCount >= 2) return { status: 'NO-GO: DO NOT RELEASE (CAUTION)', type: 'warning' };
  if (cautionCount === 1) return { status: 'GO WITH CAUTION: SAFE TO RELEASE', type: 'caution' };
  return { status: 'GO: SAFE TO RELEASE', type: 'success' };
}