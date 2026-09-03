/**
 * Cloud Functions entry point for Revive Firebase Backend.
 *
 * Phase 1 — Infrastructure / Foundation:
 * Initializes Firebase Admin and sets global function options.
 * No business logic or external integrations are implemented at this stage.
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Global execution options
setGlobalOptions({maxInstances: 10});
