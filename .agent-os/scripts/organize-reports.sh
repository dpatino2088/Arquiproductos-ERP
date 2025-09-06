#!/bin/bash
# 📊 ORGANIZE REPORTS SCRIPT
# Automatically organizes project reports into dated directories

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
REPORTS_DIR="docs/reports/$CURRENT_DATE"

echo "🗂️  Organizing project reports for $CURRENT_DATE..."

# Create directory structure if it doesn't exist
mkdir -p "$REPORTS_DIR/accessibility"
mkdir -p "$REPORTS_DIR/testing" 
mkdir -p "$REPORTS_DIR/analysis"
mkdir -p "$REPORTS_DIR/performance"

echo "📁 Created directory structure: $REPORTS_DIR"

# Function to move and rename files
move_report() {
    local pattern=$1
    local category=$2
    local prefix=$3
    local description=$4
    
    # Find files matching pattern
    files=($(ls -1 *${pattern}*.md 2>/dev/null))
    
    if [ ${#files[@]} -gt 0 ]; then
        echo ""
        echo "📋 Moving $category reports:"
        
        local counter=1
        for file in "${files[@]}"; do
            # Generate new filename
            local new_name=$(printf "%02d-%s.md" $counter "$description")
            local new_path="$REPORTS_DIR/$category/$new_name"
            
            # Move and rename file
            mv "$file" "$new_path"
            echo "  ✅ $file → $category/$new_name"
            
            ((counter++))
        done
    fi
}

# Move accessibility reports
move_report "ACCESSIBILITY" "accessibility" "acc" "accessibility-report"
move_report "WCAG" "accessibility" "wcag" "wcag-compliance"
move_report "ARIA" "accessibility" "aria" "aria-implementation"
move_report "SKIP" "accessibility" "skip" "skip-links"
move_report "KEYBOARD" "accessibility" "kbd" "keyboard-navigation"
move_report "FOCUS" "accessibility" "focus" "focus-improvements"

# Move testing reports
move_report "TEST" "testing" "test" "test-results"
move_report "MANUAL" "testing" "manual" "manual-verification"
move_report "ENVIRONMENT" "testing" "env" "environment-setup"

# Move analysis reports
move_report "POST-FLIGHT" "analysis" "pf" "post-flight-analysis"
move_report "ANALYSIS" "analysis" "analysis" "project-analysis"
move_report "FINAL" "analysis" "final" "final-analysis"
move_report "SUCCESS" "analysis" "success" "success-report"

# Move performance reports
move_report "PERFORMANCE" "performance" "perf" "performance-report"
move_report "BENCHMARK" "performance" "bench" "benchmark-results"

# Generic catch-all for other report patterns
move_report "REPORT" "analysis" "report" "general-report"
move_report "RESULTS" "analysis" "results" "results-summary"

echo ""
echo "🎯 Report organization completed!"

# Check if any reports were moved
total_files=$(find "$REPORTS_DIR" -name "*.md" 2>/dev/null | wc -l)

if [ $total_files -gt 0 ]; then
    echo "📊 Organized $total_files report files into:"
    echo "   📁 $REPORTS_DIR/"
    
    # Show structure
    echo ""
    echo "📋 Directory structure:"
    find "$REPORTS_DIR" -name "*.md" | sort | sed 's|^|   |'
    
    # Update README if it doesn't exist
    if [ ! -f "docs/reports/README.md" ]; then
        echo ""
        echo "📝 Creating reports README..."
        
        cat > "docs/reports/README.md" << EOF
# 📊 Project Reports Archive

## 📁 Organization Structure

This directory contains all project reports organized by date and category.

### Directory Structure:
\`\`\`
docs/reports/
├── README.md
└── YYYY-MM-DD/
    ├── accessibility/    # Accessibility implementation reports
    ├── testing/         # Testing methodology and results  
    ├── analysis/        # Project analysis and outcomes
    └── performance/     # Performance metrics and benchmarks
\`\`\`

## 🔄 Maintenance

Use \`.agent-os/scripts/organize-reports.sh\` to automatically organize new reports.

**Last Updated:** $(date)
EOF
        
        echo "✅ Created docs/reports/README.md"
    fi
    
else
    echo "ℹ️  No report files found to organize"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Review organized reports in docs/reports/$CURRENT_DATE/"
echo "2. Update project documentation if needed"
echo "3. Commit changes to repository"
echo ""
echo "💡 Tip: Run this script regularly to keep reports organized!"

# Automatically organizes project reports into dated directories

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
REPORTS_DIR="docs/reports/$CURRENT_DATE"

echo "🗂️  Organizing project reports for $CURRENT_DATE..."

# Create directory structure if it doesn't exist
mkdir -p "$REPORTS_DIR/accessibility"
mkdir -p "$REPORTS_DIR/testing" 
mkdir -p "$REPORTS_DIR/analysis"
mkdir -p "$REPORTS_DIR/performance"

echo "📁 Created directory structure: $REPORTS_DIR"

# Function to move and rename files
move_report() {
    local pattern=$1
    local category=$2
    local prefix=$3
    local description=$4
    
    # Find files matching pattern
    files=($(ls -1 *${pattern}*.md 2>/dev/null))
    
    if [ ${#files[@]} -gt 0 ]; then
        echo ""
        echo "📋 Moving $category reports:"
        
        local counter=1
        for file in "${files[@]}"; do
            # Generate new filename
            local new_name=$(printf "%02d-%s.md" $counter "$description")
            local new_path="$REPORTS_DIR/$category/$new_name"
            
            # Move and rename file
            mv "$file" "$new_path"
            echo "  ✅ $file → $category/$new_name"
            
            ((counter++))
        done
    fi
}

# Move accessibility reports
move_report "ACCESSIBILITY" "accessibility" "acc" "accessibility-report"
move_report "WCAG" "accessibility" "wcag" "wcag-compliance"
move_report "ARIA" "accessibility" "aria" "aria-implementation"
move_report "SKIP" "accessibility" "skip" "skip-links"
move_report "KEYBOARD" "accessibility" "kbd" "keyboard-navigation"
move_report "FOCUS" "accessibility" "focus" "focus-improvements"

# Move testing reports
move_report "TEST" "testing" "test" "test-results"
move_report "MANUAL" "testing" "manual" "manual-verification"
move_report "ENVIRONMENT" "testing" "env" "environment-setup"

# Move analysis reports
move_report "POST-FLIGHT" "analysis" "pf" "post-flight-analysis"
move_report "ANALYSIS" "analysis" "analysis" "project-analysis"
move_report "FINAL" "analysis" "final" "final-analysis"
move_report "SUCCESS" "analysis" "success" "success-report"

# Move performance reports
move_report "PERFORMANCE" "performance" "perf" "performance-report"
move_report "BENCHMARK" "performance" "bench" "benchmark-results"

# Generic catch-all for other report patterns
move_report "REPORT" "analysis" "report" "general-report"
move_report "RESULTS" "analysis" "results" "results-summary"

echo ""
echo "🎯 Report organization completed!"

# Check if any reports were moved
total_files=$(find "$REPORTS_DIR" -name "*.md" 2>/dev/null | wc -l)

if [ $total_files -gt 0 ]; then
    echo "📊 Organized $total_files report files into:"
    echo "   📁 $REPORTS_DIR/"
    
    # Show structure
    echo ""
    echo "📋 Directory structure:"
    find "$REPORTS_DIR" -name "*.md" | sort | sed 's|^|   |'
    
    # Update README if it doesn't exist
    if [ ! -f "docs/reports/README.md" ]; then
        echo ""
        echo "📝 Creating reports README..."
        
        cat > "docs/reports/README.md" << EOF
# 📊 Project Reports Archive

## 📁 Organization Structure

This directory contains all project reports organized by date and category.

### Directory Structure:
\`\`\`
docs/reports/
├── README.md
└── YYYY-MM-DD/
    ├── accessibility/    # Accessibility implementation reports
    ├── testing/         # Testing methodology and results  
    ├── analysis/        # Project analysis and outcomes
    └── performance/     # Performance metrics and benchmarks
\`\`\`

## 🔄 Maintenance

Use \`.agent-os/scripts/organize-reports.sh\` to automatically organize new reports.

**Last Updated:** $(date)
EOF
        
        echo "✅ Created docs/reports/README.md"
    fi
    
else
    echo "ℹ️  No report files found to organize"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Review organized reports in docs/reports/$CURRENT_DATE/"
echo "2. Update project documentation if needed"
echo "3. Commit changes to repository"
echo ""
echo "💡 Tip: Run this script regularly to keep reports organized!"

# Automatically organizes project reports into dated directories

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
REPORTS_DIR="docs/reports/$CURRENT_DATE"

echo "🗂️  Organizing project reports for $CURRENT_DATE..."

# Create directory structure if it doesn't exist
mkdir -p "$REPORTS_DIR/accessibility"
mkdir -p "$REPORTS_DIR/testing" 
mkdir -p "$REPORTS_DIR/analysis"
mkdir -p "$REPORTS_DIR/performance"

echo "📁 Created directory structure: $REPORTS_DIR"

# Function to move and rename files
move_report() {
    local pattern=$1
    local category=$2
    local prefix=$3
    local description=$4
    
    # Find files matching pattern
    files=($(ls -1 *${pattern}*.md 2>/dev/null))
    
    if [ ${#files[@]} -gt 0 ]; then
        echo ""
        echo "📋 Moving $category reports:"
        
        local counter=1
        for file in "${files[@]}"; do
            # Generate new filename
            local new_name=$(printf "%02d-%s.md" $counter "$description")
            local new_path="$REPORTS_DIR/$category/$new_name"
            
            # Move and rename file
            mv "$file" "$new_path"
            echo "  ✅ $file → $category/$new_name"
            
            ((counter++))
        done
    fi
}

# Move accessibility reports
move_report "ACCESSIBILITY" "accessibility" "acc" "accessibility-report"
move_report "WCAG" "accessibility" "wcag" "wcag-compliance"
move_report "ARIA" "accessibility" "aria" "aria-implementation"
move_report "SKIP" "accessibility" "skip" "skip-links"
move_report "KEYBOARD" "accessibility" "kbd" "keyboard-navigation"
move_report "FOCUS" "accessibility" "focus" "focus-improvements"

# Move testing reports
move_report "TEST" "testing" "test" "test-results"
move_report "MANUAL" "testing" "manual" "manual-verification"
move_report "ENVIRONMENT" "testing" "env" "environment-setup"

# Move analysis reports
move_report "POST-FLIGHT" "analysis" "pf" "post-flight-analysis"
move_report "ANALYSIS" "analysis" "analysis" "project-analysis"
move_report "FINAL" "analysis" "final" "final-analysis"
move_report "SUCCESS" "analysis" "success" "success-report"

# Move performance reports
move_report "PERFORMANCE" "performance" "perf" "performance-report"
move_report "BENCHMARK" "performance" "bench" "benchmark-results"

# Generic catch-all for other report patterns
move_report "REPORT" "analysis" "report" "general-report"
move_report "RESULTS" "analysis" "results" "results-summary"

echo ""
echo "🎯 Report organization completed!"

# Check if any reports were moved
total_files=$(find "$REPORTS_DIR" -name "*.md" 2>/dev/null | wc -l)

if [ $total_files -gt 0 ]; then
    echo "📊 Organized $total_files report files into:"
    echo "   📁 $REPORTS_DIR/"
    
    # Show structure
    echo ""
    echo "📋 Directory structure:"
    find "$REPORTS_DIR" -name "*.md" | sort | sed 's|^|   |'
    
    # Update README if it doesn't exist
    if [ ! -f "docs/reports/README.md" ]; then
        echo ""
        echo "📝 Creating reports README..."
        
        cat > "docs/reports/README.md" << EOF
# 📊 Project Reports Archive

## 📁 Organization Structure

This directory contains all project reports organized by date and category.

### Directory Structure:
\`\`\`
docs/reports/
├── README.md
└── YYYY-MM-DD/
    ├── accessibility/    # Accessibility implementation reports
    ├── testing/         # Testing methodology and results  
    ├── analysis/        # Project analysis and outcomes
    └── performance/     # Performance metrics and benchmarks
\`\`\`

## 🔄 Maintenance

Use \`.agent-os/scripts/organize-reports.sh\` to automatically organize new reports.

**Last Updated:** $(date)
EOF
        
        echo "✅ Created docs/reports/README.md"
    fi
    
else
    echo "ℹ️  No report files found to organize"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Review organized reports in docs/reports/$CURRENT_DATE/"
echo "2. Update project documentation if needed"
echo "3. Commit changes to repository"
echo ""
echo "💡 Tip: Run this script regularly to keep reports organized!"
