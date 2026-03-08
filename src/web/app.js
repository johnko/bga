const API_BASE = '/v1/devcontainers';

async function refreshContainers() {
    const containerDiv = document.getElementById('container-list');
    try {
        const response = await fetch(API_BASE);
        if (!response.ok) throw new Error('Failed to load containers');

        const data = await response.json();
        renderContainerList(data.containers || data);
    } catch (error) {
        console.error('Error:', error.message);
        containerDiv.innerHTML =
            '<div class="no-containers">Error loading containers. Please refresh the page.</div>';
    }
    const detailDiv = document.getElementById('container-detail');
    detailDiv.style.display = 'none';
    containerDiv.style.display = 'grid';
}

function renderContainerList(containers) {
    const containerDiv = document.getElementById('container-list');

    if (!containers || containers.length === 0) {
        containerDiv.innerHTML = '<div class="no-containers">No running devcontainers found.</div>';
        return;
    }

    containerDiv.innerHTML = containers.map(container => `
        <div class="container-card" onclick="showContainerDetails('${container.Id}')">
            ${renderStateBadge(container)}
            <h3>${sanitize((container.Names || ['unnamed']).sort()[0])}</h3>
            ${renderMeta(container)}
        </div>
    `).join('');
}

function renderStateBadge(container) {
    const state = container.State || 'unknown';
    let emoji = '';
    let style = '';
    if (['running'].includes(state)) {
        emoji = '🐎';
        style = 'background:green;';
    } else if (['exited','stopped'].includes(state)) {
        emoji = '🛑';
        style = 'background:red;';
    } else {
        emoji = '❓';
        style = 'background:#777;';
    }
    return `<div class="state-badge" style="${style}">${emoji} <span>${state}</span></div>`;
}

function renderMeta(container) {
    const labels = container.Labels || {};
    return [
        renderLabel('Status', container.Status, "float:right; background:none;"),
        renderLabel('Id', container.Id.substr(0, 12)),
        renderLabel('Names', container.Names.join('<br/>')),
        renderLabel('Local Folder', labels["devcontainer.local_folder"]) || '',
        renderLabel('Ports', extractPorts(container.Ports)),
    ].join('');
}

function renderLabel(label, value, style="") {
    return value ?
        `<div class="meta-item" style="${style}"><span>${label}</span>${value}</div>` : '';
}

function extractPorts(ports) {
    if (!ports || ports.length === 0) return '';
    const port = ports.map(port => `
        ${port.host_ip}:${port.host_port}/${port.protocol} -> ${port.container_port}/${port.protocol}
    `).join('<br/>');
    return port;
}

function sanitize(str) {
    if (!str) return '';
    return str.replace(/[^a-zA-Z0-9 _\-]/g, '');
}

async function showContainerDetails(containerId) {
    const detailDiv = document.getElementById('container-detail');
    try {
        const response = await fetch(`${API_BASE}/${encodeURIComponent(containerId)}`);
        if (!response.ok) throw new Error('Container not found');

        const container = await response.json();
        renderDetailView(container);
    } catch (error) {
        console.error('Error:', error.message);
        detailDiv.innerHTML = '<div class="no-containers">Error loading container details.</div>';
    }
    const containerDiv = document.getElementById('container-list');
    containerDiv.style.display = 'none';
    detailDiv.style.display = 'grid';
}

function renderDetailView(container) {
    const detailDiv = document.getElementById('container-detail');
    const labels = container.Labels || {};
    const html = `
        <h2>${sanitize(container.Names?.[0] || 'Unnamed')}<span> details:</span></h2>

        <div class="detail-meta">
            <div class="meta-section">
                <h4>Info</h4>
                ${renderMetaRow('ID', container.Id)}
                ${renderMetaRow('Names', container.Names.join('<br/>') || '-')}
                ${renderMetaRow('Local Folder', labels["devcontainer.local_folder"])}
                ${renderMetaRow('State', container.State)}
                ${renderMetaRow('Status', container.Status)}
            </div>

            <div class="meta-section">
                <h4>Ports</h4>
                <div>
                    ${container.Ports?.length ?
                        container.Ports.map(port => `
                            <div class="meta-row">
                                <span class="meta-label">${
                                    (
                                        (
                                            port.container_port === 4096 &&
                                            labels["devcontainer.metadata"].match(/opencode/)
                                        ) ? 'OpenCode' : (
                                            (
                                                port.container_port === 8080 &&
                                                labels["devcontainer.metadata"].match(/ghcr.io\/coder\/devcontainer-features\/code-server/)
                                            ) ? 'Coder code-server IDE' : ''
                                        )
                                    ) }</span>
                                <span class="meta-value">${port.host_ip}:${port.host_port}/${port.protocol} -> ${port.container_port}/${port.protocol}</span>
                            </div>
                        `).join('') : '-'}
                </div>
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
