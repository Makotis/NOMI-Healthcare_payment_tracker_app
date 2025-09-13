// Healthcare Payment Tracker App
class HealthcarePaymentApp {
    constructor() {
        this.payments = [];
        this.providers = [];
        this.currentTab = 'dashboard';
        this.init();
    }

    init() {
        this.loadSampleData();
        this.setupEventListeners();
        this.renderDashboard();
        this.populateProviderDropdown();
    }

    loadSampleData() {
        this.providers = [
            { id: 1, name: 'City General Hospital', specialty: 'General Medicine', phone: '(555) 123-4567' },
            { id: 2, name: 'Dr. Smith Cardiology', specialty: 'Cardiology', phone: '(555) 234-5678' },
            { id: 3, name: 'Downtown Dental Clinic', specialty: 'Dentistry', phone: '(555) 345-6789' },
            { id: 4, name: 'Vision Care Center', specialty: 'Ophthalmology', phone: '(555) 456-7890' },
            { id: 5, name: 'Metro Dermatology', specialty: 'Dermatology', phone: '(555) 567-8901' }
        ];

        this.payments = [
            {
                id: 1,
                date: '2024-01-15',
                providerId: 1,
                serviceType: 'Annual Physical',
                totalAmount: 350.00,
                insuranceCoverage: 280.00,
                yourCost: 70.00,
                status: 'paid',
                notes: 'Routine checkup with blood work'
            },
            {
                id: 2,
                date: '2024-02-03',
                providerId: 3,
                serviceType: 'Dental Cleaning',
                totalAmount: 120.00,
                insuranceCoverage: 96.00,
                yourCost: 24.00,
                status: 'paid',
                notes: 'Semi-annual cleaning'
            },
            {
                id: 3,
                date: '2024-02-20',
                providerId: 2,
                serviceType: 'Cardiology Consultation',
                totalAmount: 450.00,
                insuranceCoverage: 360.00,
                yourCost: 90.00,
                status: 'pending',
                notes: 'Follow-up for chest pain'
            },
            {
                id: 4,
                date: '2024-03-10',
                providerId: 4,
                serviceType: 'Eye Exam',
                totalAmount: 180.00,
                insuranceCoverage: 144.00,
                yourCost: 36.00,
                status: 'overdue',
                notes: 'Annual vision screening'
            },
            {
                id: 5,
                date: '2024-03-25',
                providerId: 5,
                serviceType: 'Skin Cancer Screening',
                totalAmount: 275.00,
                insuranceCoverage: 220.00,
                yourCost: 55.00,
                status: 'paid',
                notes: 'Preventive screening'
            }
        ];
    }

    setupEventListeners() {
        // Tab navigation
        document.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const tabId = e.target.getAttribute('data-tab');
                this.switchTab(tabId);
            });
        });

        // Payment form submission
        document.getElementById('payment-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.addPayment();
        });

        // Filters
        document.getElementById('status-filter').addEventListener('change', () => this.renderPaymentsTable());
        document.getElementById('provider-filter').addEventListener('change', () => this.renderPaymentsTable());
        document.getElementById('date-filter').addEventListener('change', () => this.renderPaymentsTable());

        // Export button
        document.getElementById('export-btn').addEventListener('click', () => this.exportData());
    }

    switchTab(tabId) {
        // Update active nav link
        document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active'));
        document.querySelector(`[data-tab="${tabId}"]`).classList.add('active');

        // Update active tab content
        document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
        document.getElementById(tabId).classList.add('active');

        this.currentTab = tabId;

        // Render content based on tab
        switch(tabId) {
            case 'dashboard':
                this.renderDashboard();
                break;
            case 'payments':
                this.renderPaymentsTable();
                break;
            case 'providers':
                this.renderProviders();
                break;
        }
    }

    renderDashboard() {
        const totalPayments = this.payments.reduce((sum, payment) => sum + payment.totalAmount, 0);
        const pendingClaims = this.payments.filter(p => p.status === 'pending').length;
        const outstandingBalance = this.payments
            .filter(p => p.status !== 'paid')
            .reduce((sum, payment) => sum + payment.yourCost, 0);

        document.getElementById('total-payments').textContent = `$${totalPayments.toFixed(2)}`;
        document.getElementById('pending-claims').textContent = pendingClaims;
        document.getElementById('outstanding-balance').textContent = `$${outstandingBalance.toFixed(2)}`;

        // Render recent payments
        const recentPayments = this.payments.slice(-3).reverse();
        const recentPaymentsList = document.getElementById('recent-payments-list');
        recentPaymentsList.innerHTML = recentPayments.map(payment => {
            const provider = this.providers.find(p => p.id === payment.providerId);
            return `
                <div class="payment-item">
                    <div class="payment-info">
                        <div class="payment-provider">${provider ? provider.name : 'Unknown Provider'}</div>
                        <div class="payment-service">${payment.serviceType}</div>
                        <div class="payment-date">${new Date(payment.date).toLocaleDateString()}</div>
                    </div>
                    <div class="payment-amount">$${payment.yourCost.toFixed(2)}</div>
                    <div class="payment-status status-${payment.status}">${payment.status}</div>
                </div>
            `;
        }).join('');
    }

    renderPaymentsTable() {
        const statusFilter = document.getElementById('status-filter').value;
        const providerFilter = document.getElementById('provider-filter').value;
        const dateFilter = document.getElementById('date-filter').value;

        let filteredPayments = this.payments;

        if (statusFilter !== 'all') {
            filteredPayments = filteredPayments.filter(p => p.status === statusFilter);
        }

        if (providerFilter !== 'all') {
            filteredPayments = filteredPayments.filter(p => p.providerId.toString() === providerFilter);
        }

        if (dateFilter) {
            filteredPayments = filteredPayments.filter(p => p.date >= dateFilter);
        }

        const tbody = document.getElementById('payments-table-body');
        tbody.innerHTML = filteredPayments.map(payment => {
            const provider = this.providers.find(p => p.id === payment.providerId);
            return `
                <tr>
                    <td>${new Date(payment.date).toLocaleDateString()}</td>
                    <td>${provider ? provider.name : 'Unknown'}</td>
                    <td>${payment.serviceType}</td>
                    <td>$${payment.totalAmount.toFixed(2)}</td>
                    <td>$${payment.insuranceCoverage.toFixed(2)}</td>
                    <td>$${payment.yourCost.toFixed(2)}</td>
                    <td><span class="status-badge status-${payment.status}">${payment.status}</span></td>
                    <td>
                        <button class="btn btn-sm" onclick="app.viewPayment(${payment.id})">View</button>
                        <button class="btn btn-sm btn-danger" onclick="app.deletePayment(${payment.id})">Delete</button>
                    </td>
                </tr>
            `;
        }).join('');
    }

    renderProviders() {
        const providersGrid = document.getElementById('providers-grid');
        providersGrid.innerHTML = this.providers.map(provider => `
            <div class="provider-card">
                <h3>${provider.name}</h3>
                <p class="provider-specialty">${provider.specialty}</p>
                <p class="provider-phone">${provider.phone}</p>
                <div class="provider-stats">
                    <span>Total Visits: ${this.payments.filter(p => p.providerId === provider.id).length}</span>
                </div>
            </div>
        `).join('');
    }

    populateProviderDropdown() {
        const providerSelect = document.getElementById('provider-select');
        const providerFilter = document.getElementById('provider-filter');

        const options = this.providers.map(provider => 
            `<option value="${provider.id}">${provider.name}</option>`
        ).join('');

        providerSelect.innerHTML = '<option value="">Select Provider</option>' + options;
        providerFilter.innerHTML = '<option value="all">All Providers</option>' + options;
    }

    addPayment() {
        const formData = {
            id: this.payments.length + 1,
            date: document.getElementById('service-date').value,
            providerId: parseInt(document.getElementById('provider-select').value),
            serviceType: document.getElementById('service-type').value,
            totalAmount: parseFloat(document.getElementById('total-amount').value),
            insuranceCoverage: parseFloat(document.getElementById('insurance-coverage').value) || 0,
            yourCost: 0,
            status: document.getElementById('payment-status').value,
            notes: document.getElementById('notes').value
        };

        formData.yourCost = formData.totalAmount - formData.insuranceCoverage;

        this.payments.push(formData);
        document.getElementById('payment-form').reset();
        alert('Payment added successfully!');

        if (this.currentTab === 'dashboard') {
            this.renderDashboard();
        } else if (this.currentTab === 'payments') {
            this.renderPaymentsTable();
        }
    }

    viewPayment(id) {
        const payment = this.payments.find(p => p.id === id);
        const provider = this.providers.find(p => p.id === payment.providerId);
        
        alert(`Payment Details:
Date: ${new Date(payment.date).toLocaleDateString()}
Provider: ${provider ? provider.name : 'Unknown'}
Service: ${payment.serviceType}
Total: $${payment.totalAmount.toFixed(2)}
Insurance: $${payment.insuranceCoverage.toFixed(2)}
Your Cost: $${payment.yourCost.toFixed(2)}
Status: ${payment.status}
Notes: ${payment.notes}`);
    }

    deletePayment(id) {
        if (confirm('Are you sure you want to delete this payment?')) {
            this.payments = this.payments.filter(p => p.id !== id);
            this.renderPaymentsTable();
            if (this.currentTab === 'dashboard') {
                this.renderDashboard();
            }
        }
    }

    exportData() {
        const csvContent = "data:text/csv;charset=utf-8," 
            + "Date,Provider,Service,Total Amount,Insurance Coverage,Your Cost,Status,Notes\n"
            + this.payments.map(payment => {
                const provider = this.providers.find(p => p.id === payment.providerId);
                return [
                    payment.date,
                    provider ? provider.name : 'Unknown',
                    payment.serviceType,
                    payment.totalAmount,
                    payment.insuranceCoverage,
                    payment.yourCost,
                    payment.status,
                    payment.notes
                ].join(',');
            }).join('\n');

        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'healthcare_payments.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
}

// Initialize the app
const app = new HealthcarePaymentApp();