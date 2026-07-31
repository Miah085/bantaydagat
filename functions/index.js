const functions = require("firebase-functions/v1"); // Explicitly pull the v1 SDK
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

// The rest of your code stays exactly the same
// Change it back to this proven path:
exports.checkSensorAlerts = functions.database.ref('/bantaydagat/readings/{readingId}')
  .onWrite(async (change, context) => {
    
    // If the data was deleted, there's no alert to trigger
    if (!change.after.exists()) return null;

    const beforeData = change.before.val() || {};
    const afterData = change.after.val();

    function evaluateSensor(val, key) {
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

    function getSystemState(data) {
        const air = data.air_temperature || data.airTemp || 0;
        const water = data.temperature || data.waterTemp || 0;
        const ph = data.ph || data.pH || 7.8;
        const hum = data.humidity || 0;
        const turb = data.turbidity || 0;

        const statuses = [
            { name: 'Air Temp', val: air, unit: '°C', status: evaluateSensor(air, 'airTemp') },
            { name: 'Water Temp', val: water, unit: '°C', status: evaluateSensor(water, 'waterTemp') },
            { name: 'Humidity', val: hum, unit: '%', status: evaluateSensor(hum, 'humidity') },
            { name: 'pH', val: ph, unit: 'pH', status: evaluateSensor(ph, 'ph') },
            { name: 'Turbidity', val: turb, unit: 'NTU', status: evaluateSensor(turb, 'turbidity') }
        ];

        const cautionCount = statuses.filter(s => s.status === 'CAUTION').length;
        const dangerCount = statuses.filter(s => s.status === 'DANGER').length;

        if (dangerCount >= 1) {
            const triggers = statuses.filter(s => s.status === 'DANGER');
            return { 
                level: 'CRITICAL', 
                title: `CRITICAL NO-GO: ${triggers[0].name} Danger`, 
                body: `Recorded ${triggers[0].val}${triggers[0].unit}. Immediate action required.` 
            };
        } 
        else if (cautionCount >= 2) {
            return { 
                level: 'WARNING', 
                title: "SYSTEM NO-GO: Multiple Cautions", 
                body: `${cautionCount} parameters have shifted into the warning zone. Release halted.` 
            };
        }
        return { 
            level: 'SAFE', 
            title: "✅ Sanctuary Secured", 
            body: "Water levels have stabilized. Safe protocols re-engaged." 
        };
    }

    const prevState = getSystemState(beforeData);
    const currState = getSystemState(afterData);

    if (prevState.level !== currState.level) {
        const payload = {
            notification: {
                title: currState.title,
                body: currState.body,
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "emergency_alerts_channel",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                    },
                },
            },
            topic: "emergency_alerts"
        };

        return admin.messaging().send(payload)
            .then(response => console.log(`Push (${currState.level}) Sent Successfully:`, response))
            .catch(error => console.error("Error Sending Push:", error));
    }

    return null;
  });