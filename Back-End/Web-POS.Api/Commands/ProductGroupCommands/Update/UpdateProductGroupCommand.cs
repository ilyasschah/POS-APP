using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductGroupCommands.Update
{
    public class UpdateProductGroupCommand : IRequest<bool>
    {
        
        public UpdateProductGroupRequest Request { get; }
        public int CompanyId { get; }

        public UpdateProductGroupCommand(UpdateProductGroupRequest request,int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateProductGroupCommandHandler : IRequestHandler<UpdateProductGroupCommand, bool>
        {
            private readonly ProductGroupService _service;

            public UpdateProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(UpdateProductGroupCommand command, CancellationToken cancellationToken)
            {
                return await _service.UpdateAsync( command.Request,command.CompanyId);
            }
        }
        public class UpdateProductGroupCommandValidator : AbstractValidator<UpdateProductGroupCommand>
        {
            public UpdateProductGroupCommandValidator()
            {
                RuleFor(x => x.CompanyId).GreaterThan(0);
                RuleFor(x => x.Request.Id).GreaterThan(0);
                RuleFor(x => x.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(x => x.Request.Color).NotEmpty().MaximumLength(50);
                RuleFor(x => x.Request.Rank).GreaterThanOrEqualTo(0);
                RuleFor(x => x.Request.ParentGroupId).GreaterThan(0).When(x => x.Request.ParentGroupId.HasValue);
            }
        }
    }
}
