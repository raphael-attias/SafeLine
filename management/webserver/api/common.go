package api

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"chaitin.cn/patronus/safeline-2/management/webserver/api/response"
	"chaitin.cn/patronus/safeline-2/management/webserver/pkg/constants"
)

const VersionInfoEntrypoint = "/release/latest/version.json"

// maxVersionInfoBytes bounds the upgrade information this server reads from
// the platform. The body is parsed and logged on error, so a large or endless
// answer from a misbehaving (or hostile) endpoint must not be buffered whole.
const maxVersionInfoBytes = 1 << 20

// maxLoggedBodyBytes bounds how much of an answer from another host may be put
// into the log.
const maxLoggedBodyBytes = 256

// loggableBody renders a bounded, quoted, single line version of a response
// body that came from another host.
//
// The body is remote input, and the log is read by people and by tools that
// follow it: a verbatim body lets the other end forge log lines (or worse, if
// the log is read in a terminal) with a carriage return or an escape sequence.
// strconv.Quote escapes the newlines and the control characters, and the
// truncation keeps a misbehaving endpoint from filling the disk through the
// log file.
func loggableBody(body []byte) string {
	if len(body) > maxLoggedBodyBytes {
		return fmt.Sprintf("%s... (%d bytes in total)", strconv.Quote(string(body[:maxLoggedBodyBytes])), len(body))
	}

	return strconv.Quote(string(body))
}

type idsRequest struct {
	IDs []uint `json:"ids" form:"ids"`
}

type pageRequest struct {
	// PageSize is capped at 100: the value is handed to SQL LIMIT, so an
	// unbounded one lets a single request ask the server to load an arbitrary
	// number of rows. 100 is the largest page the console offers and the same
	// range the MCP tools accept.
	Page     int `json:"page"         form:"page,default=1"         binding:"min=1"`
	PageSize int `json:"page_size"    form:"page_size,default=10"   binding:"min=1,max=100"`
}

type versionInfoResponse struct {
	LatestVersion string `json:"latest_version"`
	RecVersion    string `json:"rec_version"`
}

func GetVersion(c *gin.Context) {
	response.Success(c, gin.H{"version": strings.TrimPrefix(constants.Version, "ce-")})
}

// GetUpgradeTips reports whether the console should suggest an upgrade. It used
// to fetch PlatformAddr + /release/latest/version.json from Chaitin's platform;
// that outbound is neutralised for the 100%-local build. The endpoint now
// answers "no upgrade" without any network I/O so the console stays happy and
// never phones home.
func GetUpgradeTips(ctx *gin.Context) {
	// SAFELOCAL: no outbound to Chaitin's platform.
	logger.Debugf("GetUpgradeTips disabled: 100%% local, no platform reach")
	response.Success(ctx, gin.H{"upgrade_tips": constants.NotUpgrade})
}
