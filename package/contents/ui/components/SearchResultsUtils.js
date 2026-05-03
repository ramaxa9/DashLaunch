function normalizedText(value) {
    return String(value || "").trim()
}

function isGenericApplicationCategory(text) {
    return text === "Application" || text === "Applications"
}

function roleIdMap(resultsModel) {
    if (!resultsModel || !resultsModel.roleNames) {
        return {}
    }

    const roleNames = resultsModel.roleNames()
    const roles = {}

    for (const roleId in roleNames) {
        roles[String(roleNames[roleId])] = Number(roleId)
    }

    return roles
}

function dataForRole(resultsModel, modelIndex, roles, roleName, fallbackRole) {
    if (roles && Object.prototype.hasOwnProperty.call(roles, roleName)) {
        return resultsModel.data(modelIndex, roles[roleName])
    }

    if (fallbackRole !== undefined) {
        return resultsModel.data(modelIndex, fallbackRole)
    }

    return undefined
}

function rowObject(resultsModel, row) {
    if (!resultsModel || row < 0 || row >= resultsModel.count) {
        return null
    }

    if (!resultsModel.index || !resultsModel.data) {
        if (resultsModel.get) {
            const item = resultsModel.get(row)
            if (item) {
                return Object.assign({ index: row }, item)
            }
        }

        return null
    }

    const modelIndex = resultsModel.index(row, 0)
    if (!modelIndex.valid) {
        return null
    }

    const roles = roleIdMap(resultsModel)

    const indexedItem = {
        index: row,
        display: String(dataForRole(resultsModel, modelIndex, roles, "display", Qt.DisplayRole) || ""),
        decoration: dataForRole(resultsModel, modelIndex, roles, "decoration", Qt.DecorationRole),
        description: String(dataForRole(resultsModel, modelIndex, roles, "description") || ""),
        category: String(dataForRole(resultsModel, modelIndex, roles, "category") || ""),
        section: String(dataForRole(resultsModel, modelIndex, roles, "section") || ""),
        id: dataForRole(resultsModel, modelIndex, roles, "id"),
        favoriteId: dataForRole(resultsModel, modelIndex, roles, "favoriteId"),
        storageId: dataForRole(resultsModel, modelIndex, roles, "storageId"),
        desktopEntryName: dataForRole(resultsModel, modelIndex, roles, "desktopEntryName"),
        menuId: dataForRole(resultsModel, modelIndex, roles, "menuId"),
        url: dataForRole(resultsModel, modelIndex, roles, "url"),
        urls: dataForRole(resultsModel, modelIndex, roles, "urls")
    }

    if (!resultsModel.get) {
        return indexedItem
    }

    const item = resultsModel.get(row)
    if (!item) {
        return indexedItem
    }

    return Object.assign({}, item, indexedItem)
}

function processedResults(resultsModel, categoryResolver, uncategorizedTitle) {
    if (!resultsModel || resultsModel.count <= 0) {
        return []
    }

    const group = {
        title: "",
        items: []
    }

    for (let row = 0; row < resultsModel.count; ++row) {
        const item = rowObject(resultsModel, row)
        if (!item) {
            continue
        }

        group.items.push(item)
    }

    if (group.items.length <= 0) {
        return []
    }

    return [group]
}

function descriptionText(matchModel) {
    return normalizedText(matchModel && matchModel.description)
}

function categoryText(matchModel, categoryResolver) {
    if (categoryResolver) {
        const resolvedCategory = normalizedText(categoryResolver(matchModel))
        if (resolvedCategory.length > 0) {
            return resolvedCategory
        }
    }

    const category = normalizedText(matchModel && (matchModel.category || matchModel.section))
    if (isGenericApplicationCategory(category)) {
        return ""
    }

    return category
}

function categoryIconName(category) {
    switch (normalizedText(category)) {
    case "Internet":
        return "applications-internet"
    case "Office":
        return "applications-office"
    case "Graphics":
        return "applications-graphics"
    case "Development":
        return "applications-development"
    case "Education":
    case "Science":
        return "applications-science"
    case "Games":
        return "applications-games"
    case "Multimedia":
        return "applications-multimedia"
    case "Utilities":
        return "applications-utilities"
    case "Settings":
        return "preferences-system"
    case "System":
        return "applications-system"
    case "Help":
        return "help-browser"
    case "Other":
        return "applications-other"
    case "Uncategorized":
        return "dialog-question"
    default:
        return "view-grid"
    }
}
