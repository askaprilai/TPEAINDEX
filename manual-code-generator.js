// Manual code generator for emergency access
function generateAccessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars
    let code = '';
    for (let i = 0; i < 8; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

// Generate a unique code for sabral@me.com $97 purchase
const accessCode = generateAccessCode();
console.log('Access Code for sabral@me.com:', accessCode);

// You can use this immediately on the site