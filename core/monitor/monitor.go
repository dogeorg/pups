package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

var pathToDogecoind string

type BlockchainInfo struct {
	Chain                string  `json:"chain"`
	Blocks               int     `json:"blocks"`
	Headers              int     `json:"headers"`
	Difficulty           float64 `json:"difficulty"`
	VerificationProgress float64 `json:"verificationprogress"`
	InitialBlockDownload bool    `json:"initialblockdownload"`
	SizeOnDisk           int64   `json:"size_on_disk"`
}

func getCredentials() (string, string, error) {
	rpcUser, err := os.ReadFile("/storage/rpcuser.txt")
	if err != nil {
		log.Printf("Error reading rpcuser.txt: %v", err)
		return "", "", err
	}

	rpcPassword, err := os.ReadFile("/storage/rpcpassword.txt")
	if err != nil {
		log.Printf("Error reading rpcpassword.txt: %v", err)
		return "", "", err
	}

	fmt.Printf("RPC User: %s\n", string(rpcUser))
	fmt.Printf("RPC Password: %s\n", string(rpcPassword))

	return string(rpcUser), string(rpcPassword), nil
}

func getRawBlockchainInfo(username, password string) (string, error) {
	cmdArgs := []string{
		filepath.Join(pathToDogecoind, "bin", "dogecoin-cli"),
		fmt.Sprintf("-rpcuser=%s", strings.TrimSpace(string(username))),
		fmt.Sprintf("-rpcpassword=%s", strings.TrimSpace(string(password))),
		fmt.Sprintf("-rpcconnect=%s", os.Getenv("DBX_PUP_IP")),
		"getblockchaininfo",
	}

	cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
	cmd.Env = append(os.Environ(), "HOME=/tmp")

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Error executing dogecoin-cli command: %v", err)
		return "", err
	}

	return string(output), nil
}

func parseRawBlockchainInfo(rawInfo string) (BlockchainInfo, error) {
	var info BlockchainInfo
	err := json.Unmarshal([]byte(rawInfo), &info)
	if err != nil {
		log.Printf("Error unmarshalling blockchain info: %v", err)
		return BlockchainInfo{}, err
	}
	return info, nil
}

func submitMetrics(info BlockchainInfo) {
	client := &http.Client{}

	// Verification progress is 0..-1, so we make it pretty text
	verificationProgress := fmt.Sprintf("%.2f%%", info.VerificationProgress*100)
	initialBlockDownload := "No"

	if info.InitialBlockDownload {
		initialBlockDownload = "Yes"
	}

	chainSize := bytesToHuman(info.SizeOnDisk)

	jsonData := map[string]interface{}{
		"chain":                  map[string]interface{}{"value": info.Chain},
		"blocks":                 map[string]interface{}{"value": info.Blocks},
		"headers":                map[string]interface{}{"value": info.Headers},
		"difficulty":             map[string]interface{}{"value": info.Difficulty},
		"verification_progress":  map[string]interface{}{"value": verificationProgress},
		"initial_block_download": map[string]interface{}{"value": initialBlockDownload},
		"chain_size_human":       map[string]interface{}{"value": chainSize},
	}

	marshalledData, err := json.Marshal(jsonData)
	if err != nil {
		log.Printf("Error marshalling blockchain info: %v", err)
		return
	}

	log.Printf("Submitting metrics: %v", jsonData)

	url := fmt.Sprintf("http://%s:%s/dbx/metrics", os.Getenv("DBX_HOST"), os.Getenv("DBX_PORT"))

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(marshalledData))
	if err != nil {
		log.Printf("Error creating request: %v", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Error sending metrics: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("Unexpected status code when submitting metrics: %d", resp.StatusCode)
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Response body: %s", string(body))
		return
	}

	log.Println("Metrics submitted successfully.")
}
func bytesToHuman(bytes int64) string {
	const (
		MB = 1024 * 1024
		GB = 1024 * MB
	)

	if bytes < GB {
		mb := float64(bytes) / MB
		return fmt.Sprintf("%.2f MB", mb)
	}

	gb := float64(bytes) / GB
	return fmt.Sprintf("%.2f GB", gb)
}

func main() {
	log.Println("Sleeping to give dogecoind time to start..")
	time.Sleep(10 * time.Second)

	username, password, err := getCredentials()
	if err != nil {
		log.Printf("Error getting credentials: %v", err)
		return
	}

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			info, err := getRawBlockchainInfo(username, password)
			if err != nil {
				log.Printf("Error getting blockchain info: %v", err)
				continue
			}

			parsedInfo, err := parseRawBlockchainInfo(info)
			if err != nil {
				log.Printf("Error parsing blockchain info: %v", err)
				continue
			}

			log.Printf("Chain: %s", parsedInfo.Chain)
			log.Printf("Blocks: %d", parsedInfo.Blocks)
			log.Printf("Headers: %d", parsedInfo.Headers)
			log.Printf("Difficulty: %f", parsedInfo.Difficulty)
			log.Printf("Verification Progress: %f", parsedInfo.VerificationProgress)
			log.Printf("Initial Block Download: %t", parsedInfo.InitialBlockDownload)
			log.Printf("Size on Disk: %d", parsedInfo.SizeOnDisk)

			submitMetrics(parsedInfo)

			log.Printf("----------------------------------------")
		}
	}
}
