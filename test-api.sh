#!/bin/bash

# API Test Script for City Population API
# Tests all endpoints with various scenarios

# Configuration
# Default: http://localhost:8080 (Kubernetes)
# For Docker Compose: API_URL=http://localhost:8000 ./test-api.sh
API_URL="${API_URL:-http://localhost:8080}"
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}City Population API - Test Suite${NC}"
echo -e "${BOLD}========================================${NC}"
echo -e "API URL: ${API_URL}\n"

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        echo -e "${RED}✗ FAILED${NC}"
    fi
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Health Check
echo -e "\n${BOLD}Test 1: Health Check${NC}"
echo "GET $API_URL/health"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/health)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 2: Insert City - Tokyo
echo -e "\n${BOLD}Test 2: Insert City - Tokyo${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 13960000}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "insert"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 3: Insert City - London
echo -e "\n${BOLD}Test 3: Insert City - London${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "London", "population": 9002488}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 4: Insert City - New York
echo -e "\n${BOLD}Test 4: Insert City - New York${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8336817}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Wait for Elasticsearch to index
echo -e "\n${YELLOW}Waiting 2 seconds for Elasticsearch to index data...${NC}"
sleep 2

# Test 5: Query City - Tokyo
echo -e "\n${BOLD}Test 5: Query City - Tokyo${NC}"
echo "GET $API_URL/city/tokyo"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/city/tokyo)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "13960000"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 6: Query City - London
echo -e "\n${BOLD}Test 6: Query City - London${NC}"
echo "GET $API_URL/city/london"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/city/london)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "9002488"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 7: Update City - Tokyo
echo -e "\n${BOLD}Test 7: Update City - Tokyo (Update Population)${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 14000000}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "update"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Wait for Elasticsearch to index
sleep 1

# Test 8: Verify Update
echo -e "\n${BOLD}Test 8: Verify Updated Population - Tokyo${NC}"
echo "GET $API_URL/city/tokyo"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/city/tokyo)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "14000000"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 9: List All Cities
echo -e "\n${BOLD}Test 9: List All Cities${NC}"
echo "GET $API_URL/cities"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/cities)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q "count"; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 10: Query Non-existent City (404)
echo -e "\n${BOLD}Test 10: Query Non-existent City (Should return 404)${NC}"
echo "GET $API_URL/city/atlantis"
RESPONSE=$(curl -s -w "\n%{http_code}" $API_URL/city/atlantis)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "404" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 11: Invalid Data - Negative Population (400)
echo -e "\n${BOLD}Test 11: Invalid Data - Negative Population (Should return 400)${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Test City", "population": -1000}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Test 12: Invalid Data - Empty City Name (422)
echo -e "\n${BOLD}Test 12: Invalid Data - Empty City Name (Should return 422)${NC}"
echo "POST $API_URL/city"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "", "population": 1000}')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "422" ]; then
    print_result 0
    ((TESTS_PASSED++))
else
    print_result 1
    ((TESTS_FAILED++))
fi

# Print Summary
echo -e "\n${BOLD}========================================${NC}"
echo -e "${BOLD}Test Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "\n${RED}${BOLD}Some tests failed! ✗${NC}"
    exit 1
fi
