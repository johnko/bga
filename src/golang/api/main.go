package api

import (
	"net/http"
	"os"
	"path/filepath"
)

func IsDashboardPath(path string) bool {
	return filepath.Dir(path) == "web"
}
