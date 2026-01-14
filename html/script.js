let config = {
    UIPosition: { x: 0.885, y: 0.015 },
    Departments: [],
    ShowOffline: true
};

let currentCounts = {};

// Listen for messages from client.lua
window.addEventListener('message', (event) => {
    const data = event.data;

    switch(data.type) {
        case 'setConfig':
            config = data.config;
            initializeUI();
            break;

        case 'updateCounts':
            currentCounts = data.counts;
            updateCountDisplay();
            break;

        case 'toggleUI':
            toggleVisibility(data.visible);
            break;
    }

    // Legacy action for sound
    if (data.action === 'playSound') {
        playDuressSound();
    }
});

function initializeUI() {
    const counter = document.getElementById('unitCounter');
    const departmentList = document.getElementById('departmentList');

    // Position the UI
    counter.style.left = `${config.UIPosition.x * 100}%`;
    counter.style.top = `${config.UIPosition.y * 100}%`;
    counter.style.transform = 'translateX(-100%)'; // Align to right edge

    // Clear existing departments
    departmentList.innerHTML = '';

    // Create department elements based on config
    config.Departments.forEach(dept => {
        const deptElement = document.createElement('div');
        deptElement.className = 'department-item';
        deptElement.setAttribute('data-dept', dept.name);
        
        // Set border color based on department color
        const rgb = dept.color ? `rgb(${dept.color.r}, ${dept.color.g}, ${dept.color.b})` : 'rgb(100, 100, 100)';
        deptElement.style.borderLeftColor = rgb;

        deptElement.innerHTML = `
            <div class="department-info">
                <img src="images/${dept.name.toLowerCase()}_logo.png" 
                     alt="${dept.displayName}" 
                     class="department-logo"
                     onerror="this.style.display='none'">
                <span class="department-name">${dept.displayName}</span>
            </div>
            <span class="department-count">00</span>
        `;

        departmentList.appendChild(deptElement);
    });

    // Show UI by default
    counter.classList.remove('hidden');
}

function updateCountDisplay() {
    config.Departments.forEach(dept => {
        const count = currentCounts[dept.name] || 0;
        const deptElement = document.querySelector(`[data-dept="${dept.name}"]`);
        
        if (deptElement) {
            const countElement = deptElement.querySelector('.department-count');
            countElement.textContent = count.toString().padStart(2, '0');

            // Add/remove offline class
            if (count === 0) {
                deptElement.classList.add('offline');
            } else {
                deptElement.classList.remove('offline');
            }

            // Hide offline departments if config says so
            if (!config.ShowOffline && count === 0) {
                deptElement.style.display = 'none';
            } else {
                deptElement.style.display = 'flex';
            }
        }
    });
}

function toggleVisibility(visible) {
    const counter = document.getElementById('unitCounter');
    if (visible) {
        counter.classList.remove('hidden');
    } else {
        counter.classList.add('hidden');
    }
}

function playDuressSound() {
    const sound = document.getElementById('duressSound');
    if (sound) {
        sound.currentTime = 0;
        sound.play().catch(err => console.log('Sound play failed:', err));
    }
}