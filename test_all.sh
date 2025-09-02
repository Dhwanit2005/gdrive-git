#!/bin/bash

echo "🚀 Testing GDrive CLI Commands..."

# Create test directory
TEST_DIR="test_$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
cp ../credentials.json .

echo ""
echo "1️⃣  Testing gdrive init..."
gdrive init test-workspace

echo ""
echo "2️⃣  Creating test files..."
echo "Hello World" > test.txt
echo "# Test README" > README.md
mkdir -p docs
echo "Documentation" > docs/guide.md

echo ""
echo "3️⃣  Testing gdrive add..."
gdrive add test.txt
gdrive add README.md

echo ""
echo "4️⃣  Testing gdrive ls..."
gdrive ls

echo ""
echo "5️⃣  Testing gdrive status..."
gdrive status

echo ""
echo "6️⃣  Testing gdrive cat..."
gdrive cat test.txt

echo ""
echo "7️⃣  Testing gdrive push..."
echo "Modified content" >> README.md
gdrive push -f

echo ""
echo "8️⃣  Testing gdrive pull..."
rm test.txt
gdrive pull -f
ls test.txt  # Should be restored

echo ""
echo "9️⃣  Testing gdrive rm..."
gdrive rm -f test.txt

echo ""
echo "🎉 All tests completed!"

# Cleanup
cd ..
rm -rf "$TEST_DIR"
