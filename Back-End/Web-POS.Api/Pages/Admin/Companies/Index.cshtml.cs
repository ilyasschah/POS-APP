using Api.Admin;
using Api.Commands.CompanyCommands.Delete;
using Api.Models;
using Api.Queries.CompanyQuery;
using Api.Services;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.Net.Http.Headers;
using System.Security.Cryptography;

namespace Api.Pages.Admin.Companies;

public class IndexModel : PageModel
{
    private readonly IMediator _mediator;
    public IndexModel(IMediator mediator) => _mediator = mediator;

    public List<CompanyDto> Companies { get; private set; } = new();

    public async Task OnGetAsync()
    {
        Companies = await _mediator.Send(new GetAllCompaniesQuery());
    }

    /// <summary>
    /// Serves one company's logo so the list can show it with a plain
    /// &lt;img src&gt;.
    ///
    /// The bytes are NOT inlined as a data: URI in the table. They are already
    /// in hand — CompanyDto carries them — but base64 inflates by a third and a
    /// portal listing a few hundred tenants would ship megabytes of image on
    /// every page load. Served separately they are fetched in parallel and
    /// cached; the ETag is the content itself, so a replaced logo appears at
    /// once instead of waiting out a max-age.
    /// </summary>
    public async Task<IActionResult> OnGetLogoAsync(int id)
    {
        var company = await _mediator.Send(new GetCompanyByIdQuery(id));
        var contentType = CompanyLogoFile.ContentType(company?.Logo);
        if (company?.Logo is null || contentType is null) return NotFound();

        var tag = Convert.ToHexString(MD5.HashData(company.Logo));
        // Built directly rather than via File(...): PageModel's overloads take a
        // download file name, not an ETag, and naming the file would serve the
        // logo as an attachment instead of an image.
        return new FileContentResult(company.Logo, contentType)
        {
            EntityTag = new EntityTagHeaderValue($"\"{tag}\""),
        };
    }

    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        try
        {
            await _mediator.Send(new DeleteCompanyCommand(id));
            TempData["Success"] = "Company and all its data were deleted.";
        }
        catch (CompanyPartiallyDeletedException ex)
        {
            // The company's own data IS gone — only the Master-DB licensing
            // tenant survived. Reporting a plain "Delete failed" would be a lie
            // in the other direction, and reporting success (what this page used
            // to do, because the failure was swallowed as a LogWarning) is why
            // "I deleted a company and it didn't delete all its data" went
            // unnoticed. Say exactly what is left.
            TempData["Warning"] = ex.Message;
        }
        catch (Exception ex)
        {
            TempData["Error"] = $"Delete failed: {ex.Message}";
        }
        return RedirectToPage();
    }
}
