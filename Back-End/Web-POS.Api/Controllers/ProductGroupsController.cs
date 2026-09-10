using Api.Attributes;
using Api.Commands.ProductGroupCommands.Add;
using Api.Commands.ProductGroupCommands.AssignProducts;
using Api.Commands.ProductGroupCommands.Delete;
using Api.Commands.ProductGroupCommands.Import;
using Api.Commands.ProductGroupCommands.Update;
using Api.Models;
using Api.Queries.ProductGroupsQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class ProductGroupsController : ControllerBase
    {
        private readonly IMediator _mediator;

        public ProductGroupsController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetAllProductGroupsQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductGroupDto>> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetProductGroupByIdQuery { Id = id, CompanyId = companyId }, ct));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetChildren([FromQuery] int parentId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            if (parentId <= 0) return BadRequest("Parent ID is required");

            return Ok(await _mediator.Send(new GetProductGroupChildrenQuery { ParentId = parentId, CompanyId = companyId }, ct));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<ProductGroupDto>> Add([FromBody] CreateProductGroupRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new AddProductGroupCommand(request, companyId), ct);
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateProductGroupRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new UpdateProductGroupCommand(request,companyId ), ct);
            return Ok(new { Success = result });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new DeleteProductGroupCommand(id, companyId), ct);
            return Ok(new { Message = result ? "Product Group deleted successfully" : "Failed to delete group" });
        }

        /// <summary>Every group, parents first, without images — for export.</summary>
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupExportDto>>> GetForExport(
            [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await _mediator.Send(new GetProductGroupsForExportQuery { CompanyId = companyId }, ct));
        }

        /// <summary>
        /// Creates or merges groups from a CSV/XML import, parents resolved by name
        /// in any row order. Per-row problems come back in the result, not as a 500.
        /// </summary>
        [HttpPost("[action]")]
        public async Task<ActionResult<ImportProductGroupsResult>> ImportBulk(
            [FromBody] ImportProductGroupsRequest request, CancellationToken ct = default)
        {
            if (request.CompanyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (request.Rows == null || request.Rows.Count == 0)
                return BadRequest(new { message = "No rows to import" });
            return Ok(await _mediator.Send(new ImportProductGroupsCommand(request), ct));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> AssignProducts([FromBody] AssignProductsToGroupRequest request, CancellationToken ct = default)
        {
            if (request.CompanyId <= 0) return BadRequest("Company ID is required");
            if (request.GroupId <= 0) return BadRequest("Group ID is required");
            var updated = await _mediator.Send(new AssignProductsToGroupCommand(request), ct);
            return Ok(new { Updated = updated });
        }
    }
}