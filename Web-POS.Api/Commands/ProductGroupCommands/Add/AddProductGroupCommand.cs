using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductGroupCommands.Add
{
    public class AddProductGroupCommand : IRequest<ProductGroupDto>
    {
        public CreateProductGroupRequest Request { get; set; }
        public int CompanyId { get; set; }

        public AddProductGroupCommand(CreateProductGroupRequest request, int companyid)
        {
            Request = request;
            CompanyId = companyid;
        }

        public class AddProductGroupCommandHandler : IRequestHandler<AddProductGroupCommand, ProductGroupDto>
        {
            private readonly ProductGroupService _service;

            public AddProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public async Task<ProductGroupDto> Handle(AddProductGroupCommand command, CancellationToken cancellationToken)
            {
                return await _service.CreateAsync(command.Request, command.CompanyId);
            }
        }
    }
    public class AddProductGroupCommandValidator : AbstractValidator<AddProductGroupCommand>
    {
        public AddProductGroupCommandValidator()
        {
            RuleFor(c => c.Request.Name).NotNull().NotEmpty().WithMessage("Product Group name is required.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
