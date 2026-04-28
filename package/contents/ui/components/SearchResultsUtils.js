function hasSections(resultsModel) {
    return !!(resultsModel && resultsModel.sections && resultsModel.sections.count > 0)
}

function sectionTitle(resultsModel, sectionIndex) {
    if (!resultsModel || !resultsModel.sections) {
        return ""
    }

    const modelIndex = resultsModel.sections.index(sectionIndex, 0)
    if (!modelIndex.valid) {
        return ""
    }

    return String(resultsModel.sections.data(modelIndex, Qt.DisplayRole) || "")
}

function categoryText(matchModel) {
    return String((matchModel && matchModel.section) || "")
}
