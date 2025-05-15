const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteManager = functions.https.onCall(async (data, context) => {
    const email = data.email;  // Get the manager's email

    try {
        const user = await admin.auth().getUserByEmail(email);
        await admin.auth().deleteUser(user.uid);
        return { success: true, message: `User ${email} deleted successfully!` };
    } catch (error) {
        return { success: false, message: `Error: ${error.message}` };
    }
});
