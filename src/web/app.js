const API_BASE = '/v1/devcontainers';

async function refreshContainers() {
    try {
        const response = await fetch(API_BASE);
        if (!response.ok) throw new Error('Failed to load containers');
        
        const data = await response.json();
        renderContainerList(data.containers || data);
    } catch (error) {
        console.error('Error:', error.message);
        document.getElementById('container-list').innerHTML = 
            '<div class="no-containers">Error loading containers. Please refresh the page.</div>';
    }
}

function renderContainerList(containers) {
    const containerDiv = document.getElementById('container-list');
    
    if (!containers || containers.length === 0) {
        containerDiv.innerHTML = '<div class="no-containers">No running devcontainers found.</div>';
        return;
    }
    
    containerDiv.innerHTML = containers.map(container => `
        <div class="container-card" onclick="showContainerDetails('${container.Id}')">
            <h3>${sanitize(container.Names?.[0] || 'Unnamed')}</h3>
            ${renderMeta(container)}
        </div>
    `).join('');
}

function renderMeta(container) {
    const labels = container.Labels || {};
    return [
        renderLabel('Id', container.Id),
        renderLabel('Name', container.Names?.[0]),
        renderLabel('Port', extractPort(container.Ports)),
        renderLabel('Source', labels.dev__containers__source) || '',
        renderLabel('Variant', labels.dev__containers__variant) || ''
    ].join('');
}

function renderLabel(label, value) {
    return value ? 
        `<div class="meta-item"><span>${label}</span>${value}</div>` : '';
}

function extractPort(ports) {
    if (!ports || ports.length === 0) return '';
    const port = ports.find(p => p.protocol === 'tcp');
    return port ? `Port ${port.host_port}:->${p.container_port}`.replace('p.', '') : '';
}

function sanitize(str) {
    if (!str) return '';
    return str.replace(/[^a-zA-Z0-9 _\-]/g, '');
}

async function showContainerDetails(containerId) {
    const detailDiv = document.getElementById('container-detail');
    containerDiv.style.display = 'none';
    detailDiv.style.display = 'block';
    
    try {
        const response = await fetch(`${API_BASE}/${encodeURIComponent(containerId)}`);
        if (!response.ok) throw new Error('Container not found');
        
        const container = await response.json();
        renderDetailView(container);
    } catch (error) {
        console.error('Error:', error.message);
        detailDiv.innerHTML = '<div class="no-containers">Error loading container details.</div>';
    }
}

function renderDetailView(container) {
    const labels = container.Labels || {};
    const html = `
        <h2>${sanitize(container.Names?.[0] || 'Unnamed')}</h2>
        
        <div class="detail-meta">
            <div class="meta-section">
                <h4>Identification</h4>
                ${renderMetaRow('ID', container.Id).concat(
                    renderMetaRow('Name', container.Names?.[0] || '-')}.join('')
                </div>
                
            <div class="meta-section">
                <h4>Ports</h4>
                <div style="display: grid; gap: 8px;">
                    ${container.Ports?.length ? 
                        container.Ports.map(port => `
                            <div class="meta-row">
                                <span class="meta-label">${port.protocol}</span>
                                <span class="meta-value">${port.host_ip}:${port.host_port} -> ${port.container_port}</span>
                            </div>
                        `).join('') : 'No ports exposed'}
                </div>
            </div>
            
            <div class="meta-section">
                <h4>${labels.dev__containers__source ? 'Deployment' : 'Info'}</h4>
                ${container.Labels?.['dev.containers.source'] ? 
                    renderMetaRow('Source', labels.dev__containers__source).concat(
                        renderMetaRow('Variant', labels.dev__containers__variant)).join('', '') : ''}.concat(
                    renderMetaRow('Release', labels.dev__containers__release || '-'))
            </div>
        </div>
    `;
    
    if (!container.Labels?.['dev.containers.source']) {
        html = `<div class="no-containers">No devcontainers found with matching ID.</div>`;
    }
    
    detailDiv.innerHTML = html;
}

function renderMetaRow(label, value) {
    if (!value) return '';
    return `<div class="meta-row"><span class="meta-label">${label}</span><span class="meta-value">${value}</span></div>`;
}

document.getElementById('refresh-btn').addEventListener('click', refreshContainers);

document.addEventListener('DOMContentLoaded', () => {
    refreshContainers();
});
