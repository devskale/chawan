chawan ascii mode

Implement a proof-of-concept for ASCII image mode in the Chawan terminal web browser, focusing initially on rendering images as ASCII art boxes. The implementation should follow these detailed specifications:

1. Architecture Analysis:

   - Thoroughly review Chawan's documentation and source code to understand:
     - The current image rendering pipeline
     - Configuration system architecture
     - Terminal output mechanisms

2. ASCII Mode Implementation:

   - Add a new configuration option in `./config.toml`:
     ```
     [display]
     image-mode = "ascii"  # Options: "default", "sixel", "ascii"
     ascii-color = "gray"  # Default color tone for ASCII art
     ```
   - Create an ASCII renderer component that:
     - Accepts image dimensions as input
     - Generates an ASCII art box using configured color tone
     - Maintains proper aspect ratio
     - Uses monospace character patterns for consistent rendering

3. Testing Protocol:

   - Build Chawan with ASCII mode enabled using `make`
   - Test using `./sites/coffee.html` as a reference page
   - Verify terminal output shows ASCII art boxes instead of images
   - Check different color tone configurations
   - Validate behavior with various image sizes

4. Success Criteria:

   - Proof that:
     - The image rendering pipeline can be extended for ASCII mode
     - ASCII art boxes render correctly in terminal
     - Configuration system properly handles the new options
   - Clean, maintainable code following Chawan's existing style
   - Proper documentation of the new feature

5. Implementation Constraints:

   - Only focus on ASCII art box rendering for this phase
   - Maintain backward compatibility with existing image modes
   - Keep performance impact minimal
   - Follow Chawan's coding conventions and architecture patterns

6. Deliverables:
   - Modified source code with ASCII mode implementation
   - Updated documentation
   - Testing instructions
   - Brief implementation report showing POC results

Note: Subsequent phases will address additional ASCII art features and optimizations. This POC should establish the foundational architecture for ASCII image support.
