const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

exports.checkSensorAlerts = functions.database.ref('/bantaydagat/readings/{readingId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.val();

    const air = data.air_temperature || data.airTemp || 0;
    const water = data.temperature || data.waterTemp || 0;
    const ph = data.ph || data.pH || 7.8;
    const hum = data.humidity || 0;
    const turb = data.turbidity || 0;

    function evaluateSensor(val, key) {
        // UPDATED TURBIDITY LIMITS
        if (key === 'turbidity') {
            if (val > 50.00) return 'DANGER';
            if (val > 25.00) return 'CAUTION';
            return 'SAFE';
        }
        
        const thresholds = {
            'airTemp': { safe: [25.00, 32.00], caution: [22.00, 35.00] },
            'waterTemp': { safe: [26.00, 31.00], caution: [24.00, 33.00] },
            'humidity': { safe: [65.00, 85.00], caution: [55.00, 90.00] },
            'ph': { safe: [7.80, 8.30], caution: [7.50, 8.50] }
        };

        const t = thresholds[key];
        if (val < t.caution[0] || val > t.caution[1]) return 'DANGER';
        if (val >= t.safe[0] && val <= t.safe[1]) return 'SAFE';
        return 'CAUTION';
    }

    const statuses = [
        { name: 'Air Temp', val: air, unit: '°C', status: evaluateSensor(air, 'airTemp') },
        { name: 'Water Temp', val: water, unit: '°C', status: evaluateSensor(water, 'waterTemp') },
        { name: 'Humidity', val: hum, unit: '%', status: evaluateSensor(hum, 'humidity') },
        { name: 'pH', val: ph, unit: 'pH', status: evaluateSensor(ph, 'ph') },
        { name: 'Turbidity', val: turb, unit: 'NTU', status: evaluateSensor(turb, 'turbidity') }
    ];

    const cautionCount = statuses.filter(s => s.status === 'CAUTION').length;
    const dangerCount = statuses.filter(s => s.status === 'DANGER').length;

    let alertTitle = null;
    let alertBody = null;

    if (dangerCount >= 1) {
        const triggers = statuses.filter(s => s.status === 'DANGER');
        alertTitle = `CRITICAL NO-GO: ${triggers[0].name} Danger`;
        alertBody = `Recorded ${triggers[0].val}${triggers[0].unit}. Immediate action required.`;
    } 
    else if (cautionCount >= 2) {
        alertTitle = "SYSTEM NO-GO: Multiple Cautions";
        alertBody = `${cautionCount} parameters have shifted into the warning zone. Release halted.`;
    }

    if (alertTitle) {
        const payload = {
            notification: {
                title: alertTitle,
                body: alertBody,
            },
            topic: "emergency_alerts"
        };

        return admin.messaging().send(payload)
            .then(response => console.log("Push Notification Sent Successfully:", response))
            .catch(error => console.error("Error Sending Push:", error));
    }

    return null;
  });