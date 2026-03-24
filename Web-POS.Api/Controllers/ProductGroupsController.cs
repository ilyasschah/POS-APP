using Api.Attributes;
using Api.Commands.ProductGroupCommands.Add;
using Api.Commands.ProductGroupCommands.Delete;
using Api.Commands.ProductGroupCommands.Update;
using Api.Models;
using Api.Queries.ProductGroupQuery;
using Api.Queries.ProductGroupsQuery;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers
{
    [SwaggerVisible]
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
        public async Task<ActionResult<List<ProductGroupDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetAllProductGroupsQuery { CompanyId = companyId }));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductGroupDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            return Ok(await _mediator.Send(new GetProductGroupByIdQuery { Id = id, CompanyId = companyId }));
        }
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetChildren([FromQuery] int parentId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            if (parentId <= 0) return BadRequest("Parent ID is required");

            return Ok(await _mediator.Send(new GetProductGroupChildrenQuery { ParentId = parentId, CompanyId = companyId }));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<ProductGroupDto>> Add([FromBody] CreateProductGroupRequest request, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new AddProductGroupCommand(request, companyId));
            return Ok(result);
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateProductGroupRequest request, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new UpdateProductGroupCommand(request,companyId ));
            return Ok(new { Success = result });
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await _mediator.Send(new DeleteProductGroupCommand(id, companyId));
            return Ok(new { Message = result ? "Product Group deleted successfully" : "Failed to delete group" });
        }
    }
}