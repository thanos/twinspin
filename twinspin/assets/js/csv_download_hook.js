export default {
  mounted() {
    this.handleEvent("download_csv", ({ filename, content }) => {
      // Create a blob from the CSV content
      const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });

      // Create a temporary download link
      const link = document.createElement("a");
      const url = URL.createObjectURL(blob);

      link.setAttribute("href", url);
      link.setAttribute("download", filename);
      link.style.visibility = "hidden";

      // Append to body, click, and remove
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      // Clean up the URL object
      URL.revokeObjectURL(url);
    });
  },
};
