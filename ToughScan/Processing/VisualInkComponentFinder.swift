struct VisualInkComponentFinder {
    func connectedComponents(
        in mask: [Bool],
        width: Int,
        height: Int
    ) -> [VisualInkComponent] {
        var visited = Array(repeating: false, count: mask.count)
        var components: [VisualInkComponent] = []

        for index in mask.indices where mask[index] && !visited[index] {
            var stack = [index]
            visited[index] = true
            var component = VisualInkComponent()

            while let current = stack.popLast() {
                let x = current % width
                let y = current / width
                component.include(x: x, y: y)

                for neighbor in neighbors(ofX: x, y: y, width: width, height: height) {
                    guard mask[neighbor], !visited[neighbor] else {
                        continue
                    }

                    visited[neighbor] = true
                    stack.append(neighbor)
                }
            }

            components.append(component)
        }

        return components
    }

    private func neighbors(ofX x: Int, y: Int, width: Int, height: Int) -> [Int] {
        var result: [Int] = []

        for yOffset in -1...1 {
            for xOffset in -1...1 where !(xOffset == 0 && yOffset == 0) {
                let nextX = x + xOffset
                let nextY = y + yOffset
                guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else {
                    continue
                }

                result.append((nextY * width) + nextX)
            }
        }

        return result
    }
}
