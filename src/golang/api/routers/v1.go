package routers

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
)

type PublishedPort struct {
	HostIP       string `json:"host_ip"`
	HostPort     int    `json:"host_port"`
	ContainerPort int   `json:"container_port"`
	Protocol     string `json:"protocol"`
}

type Labels struct {
	DotContainersID              string `json:"dev.containers.id"`
	DotContainersRelease         string `json:"dev.containers.release"`
	DotContainersSource          string `json:"dev.containers.source"`
	DotContainersTimestamp       string `json:"dev.containers.timestamp"`
	DotContainersVariant         string `json:"dev.containers.variant"`
	DotContainerLocalFolder      string `json:"devcontainer.local_folder"`
	OrgOpencontainersImageRefName string `json:"org.opencontainers.image.ref.name"`
	OrgOpencontainersImageVersion string `json:"org.opencontainers.image.version"`
	Version                      string `json:"version"`
}

type Devcontainer struct {
	Id             string          `json:"Id"`
	Name           []string        `json:"Names"`
	Ports          []PublishedPort `json:"Ports"`
	Labels         Labels          `json:"Labels"`
	CodeServerProxy *CodeServerInfo      `json:"codeserver_proxy,omitempty"`
}

type CodeServerInfo struct {
	ProxyPath    string `json:"proxy_path"`
	HostPort     int    `json:"host_port"`
	ContainerPort int   `json:"container_port"`
}

func dockerpsJSON() ([]Devcontainer, error) {
	c, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		return nil, fmt.Errorf("failed to create docker client: %w", err)
	}
	defer c.Close()

	containers, err := c.ContainerList(context.Background(), types.ContainerListOptions{
		All:     true,
		Filters: map[string][]string{"label": {"devcontainer.local_folder"}},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to list containers: %w", err)
	}

	var homedir string
	if home, _ := os.UserHomeDir(); home != "" {
		homedir = home
	}

	result := make([]Devcontainer, 0, len(containers))
	for _, container := range containers {
		item := Devcontainer{
			Id:   container.ID,
			Name: container.Names,
		}

		if labelsRaw, ok := container.Labels["devcontainer.local_folder"]; ok {
			replaced := strings.ReplaceAll(labelsRaw, homedir, "~")
			item.Labels = Labels{
				DotContainerLocalFolder: replaced,
			}
			for key, value := range container.Labels {
				if key != "devcontainer.local_folder" {
					switch key {
					case "dev.containers.id":
						item.Labels.DotContainersID = value
					case "dev.containers.release":
						item.Labels.DotContainersRelease = value
					case "dev.containers.source":
						item.Labels.DotContainersSource = value
					case "dev.containers.timestamp":
						item.Labels.DotContainersTimestamp = value
					case "dev.containers.variant":
						item.Labels.DotContainersVariant = value
					case "org.opencontainers.image.ref.name":
						item.Labels.OrgOpencontainersImageRefName = value
					case "org.opencontainers.image.version":
						item.Labels.OrgOpencontainersImageVersion = value
					default:
						item.Labels.Version = value
					}
				}
			}

			if metadata, ok := container.Labels["devcontainer.metadata"]; ok && metadata != "" {
				if strings.Contains(metadata, "code-server") && len(container.Ports) > 0 {
					for _, p := range container.Ports {
						portMap := make(map[string]string)
						err = json.Unmarshal([]byte(p), &portMap)
						if err == nil {
							if hostIP, portOk := portMap["host_ip"]; portOk && hostIP == "127.0.0.1" {
								if containerPort, ok := portMap["container_port"]; ok && containerPort == "8080" {
									codeServerProxy := &CodeServerInfo{
										ProxyPath:    fmt.Sprintf("/proxy/codeserver/%s/", strings.Split(strings.TrimPrefix(container.Id, "sha256:")[0], ":" )[0]),
										HostPort:     parseInt(portMap["host_port"]),
										ContainerPort: parseInt(portMap["container_port"]),
									}
									item.CodeServerProxy = codeServerProxy
								}
							}
						}
					}
				}
			}

			if len(container.Ports) > 0 {
				var ports []PublishedPort
				for _, p := range container.Ports {
					portMap := make(map[string]string)
					err := json.Unmarshal([]byte(p), &portMap)
					if err == nil {
						ports = append(ports, PublishedPort{
							HostIP:       portMap["host_ip"],
							HostPort:     parseInt(portMap["host_port"]),
							ContainerPort: parseInt(portMap["container_port"]),
							Protocol:     portMap["protocol"]}

					}
				}
				item.Ports = ports
			}
		}
		result = append(result, item)
	}
	return result, nil
}

func parseInt(s string) int {
	var result int
	fmt.Sscanf(s, "%d", &result)
	return result
}
