package pkg

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"chaitin.cn/patronus/safeline-2/management/webserver/pkg/constants"
	"chaitin.cn/patronus/safeline-2/management/webserver/utils"
)

type WebsiteResult struct {
	Id        uint
	UpdatedAt time.Time
}

type TelemetryInfo struct {
	Id string `json:"id"`
}

type SafelineInfo struct {
	Id string `json:"id"`

	Type    string `json:"type"`
	Version string `json:"version"`

	ReqCnt         int  `json:"req_cnt"`
	DetectLogCnt   int  `json:"detect_log_cnt"`
	SiteCnt        int  `json:"site_cnt"`
	HealthySiteCnt int  `json:"healthy_site_cnt"`
	RuleCnt        int  `json:"rule_cnt"`
	IsHealthy      bool `json:"is_healthy"`

	Behavior    map[string]int  `json:"behavior"`
	Websites    []WebsiteResult `json:"websites"`
	WebsitesCnt int             `json:"websites_cnt"`
}

type TelemetryRequest struct {
	Telemetry TelemetryInfo `json:"telemetry"`
	Safeline  SafelineInfo  `json:"safeline"`
}

func GetUploadTimestamp() string {
	yesterday := time.Now().AddDate(0, 0, -1)
	yesterdayNoon := time.Date(yesterday.Year(), yesterday.Month(), yesterday.Day(), 12, 0, 0, 0, yesterday.Location())
	return strconv.FormatInt(yesterdayNoon.Unix(), 10)
}

func GetUploadNonce() string {
	now := strconv.FormatInt(time.Now().Unix(), 10)
	randStr := utils.RandStr(6)
	return fmt.Sprintf("%s%s", now, randStr)
}

// DoPostTelemetry is neutralised for the 100%-local build. SafeLine must never
// phone home to Chaitin's telemetry endpoint, so this function performs no
// network I/O: it drains the caller's reader and returns a synthetic 200 OK so
// that its two callers (NotifyInstallation, PostFalsePositives) keep their
// contract without leaking the reader or opening any outbound connection.
func DoPostTelemetry(client *http.Client, addr string, reader io.Reader) (*http.Response, error) {
	_ = client
	_ = addr
	if reader != nil {
		_, _ = io.Copy(io.Discard, reader)
	}
	resp := &http.Response{
		StatusCode: http.StatusOK,
		Status:     "200 OK",
		Body:       io.NopCloser(strings.NewReader(`{"ok":true}`)),
		Header:     make(http.Header),
	}
	resp.Header.Set("Content-Type", constants.ApplicationJson)
	return resp, nil
}
