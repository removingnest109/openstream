package webassets

import (
	"embed"
	"io/fs"
)

//go:embed all:frontend/build
var embeddedFiles embed.FS

func ReactBuildFS() (fs.FS, error) {
	return fs.Sub(embeddedFiles, "frontend/build")
}
