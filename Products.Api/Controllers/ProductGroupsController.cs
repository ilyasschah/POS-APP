using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductGroupCommands.Add;
using Products.Api.Commands.ProductGroupCommands.Delete;
using Products.Api.Commands.ProductGroupCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.ProductGroupQuery;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductGroupsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetAll()
        {
            var result = await mediator.Send(new GetAllProductGroupsQuery());
            return Ok(result);
        }

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<ProductGroupDto>> GetById(int id)
        {
            var result = await mediator.Send(new GetProductGroupByIdQuery { Id = id });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{name}")]
        public async Task<ActionResult<ProductGroupDto>> GetByName(string name)
        {
            var result = await mediator.Send(new GetProductGroupByNameQuery { Name = name });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{parentGroupId:int}")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetChildrenByParentId(int parentGroupId)
        {
            var result = await mediator.Send(new GetChildrenByParentIdQuery { ParentGroupId = parentGroupId });
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductGroupDto>>> GetRoots()
        {
            var result = await mediator.Send(new GetRootProductGroupsQuery());
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ProductGroupDto>> Add([FromQuery] CreateProductGroupRequest req)
        {
            var result = await mediator.Send(new AddProductGroupCommand(req));
            return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
        }

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id, [FromQuery] UpdateProductGroupRequest req)
        {
            var ok = await mediator.Send(new UpdateProductGroupCommand(id, req));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var ok = await mediator.Send(new DeleteProductGroupCommand(id));
            return ok ? NoContent() : NotFound();
        }
    }
}
